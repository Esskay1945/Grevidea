//! One durable activity ledger shared by every device. Values are labeled estimates.
use crate::{
    auth::AuthUser,
    error::{AppError, AppResult},
    models::ApiResponse,
    AppState,
};
use axum::{
    extract::{Query, State},
    Json,
};
use chrono::{DateTime, Utc};
use serde::Deserialize;
use serde_json::{json, Value};
use uuid::Uuid;
fn uid(auth: &AuthUser) -> AppResult<Uuid> {
    Uuid::parse_str(&auth.0.sub).map_err(|_| AppError::Auth("Invalid account".into()))
}
#[derive(Deserialize)]
pub struct Activity {
    pub client_id: String,
    pub category: String,
    pub title: String,
    pub subtitle: Option<String>,
    pub co2_delta_kg: f64,
    pub occurred_at: DateTime<Utc>,
}
pub async fn record(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(r): Json<Activity>,
) -> AppResult<Json<ApiResponse<Value>>> {
    if r.client_id.is_empty()
        || r.client_id.len() > 100
        || !["Transport", "Energy", "Food", "Waste"].contains(&r.category.as_str())
        || r.title.trim().is_empty()
        || r.title.len() > 200
        || r.subtitle.as_ref().is_some_and(|s| s.len() > 2000)
        || !r.co2_delta_kg.is_finite()
        || r.co2_delta_kg.abs() > 10000.
        || r.occurred_at > Utc::now() + chrono::Duration::minutes(5)
        || r.occurred_at < Utc::now() - chrono::Duration::days(366)
    {
        return Err(AppError::BadRequest("Invalid activity or timestamp".into()));
    }
    let row:Value=sqlx::query_scalar("INSERT INTO activity_events(user_id,client_id,category,title,subtitle,co2_delta_kg,occurred_at) VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(user_id,client_id) DO UPDATE SET client_id=EXCLUDED.client_id RETURNING to_jsonb(activity_events)").bind(uid(&auth)?).bind(r.client_id).bind(r.category).bind(r.title).bind(r.subtitle.unwrap_or_default()).bind(r.co2_delta_kg).bind(r.occurred_at).fetch_one(&state.db).await?;
    Ok(Json(ApiResponse::ok(row)))
}
#[derive(Deserialize)]
pub struct History {
    pub days: Option<i64>,
}
pub async fn history(
    State(state): State<AppState>,
    auth: AuthUser,
    Query(q): Query<History>,
) -> AppResult<Json<ApiResponse<Value>>> {
    let days = q.days.unwrap_or(366);
    if !(1..=366).contains(&days) {
        return Err(AppError::BadRequest(
            "History window must be 1–366 days".into(),
        ));
    }
    let rows:Vec<Value>=sqlx::query_scalar("SELECT to_jsonb(a) FROM activity_events a WHERE user_id=$1 AND occurred_at>=NOW()-make_interval(days=>$2::int) ORDER BY occurred_at DESC LIMIT 10001").bind(uid(&auth)?).bind(days as i32).fetch_all(&state.db).await?;
    if rows.len() > 10000 {
        return Err(AppError::BadRequest(
            "History exceeds 10000 events; export/archive older events".into(),
        ));
    }
    Ok(Json(ApiResponse::ok(
        json!({"activities":rows,"source":"synchronized user-reported estimates","days":days}),
    )))
}
#[derive(Deserialize)]
pub struct Baseline {
    pub profile: Value,
    pub completed: bool,
}
pub fn validate_baseline(p: &Value) -> AppResult<()> {
    if !p.is_object() || p.to_string().len() > 10000 {
        return Err(AppError::BadRequest("Invalid baseline profile".into()));
    }
    for key in ["dailyCommuteKm", "monthlyElectricityKwh"] {
        if let Some(v) = p.get(key) {
            let n = v.as_f64().ok_or_else(|| {
                AppError::BadRequest("Baseline quantities must be numeric".into())
            })?;
            if !n.is_finite() || !(0.0..=10000.).contains(&n) {
                return Err(AppError::BadRequest("Invalid baseline quantity".into()));
            }
        }
    }
    if let Some(distances) = p.get("commuteDistances") {
        let map = distances
            .as_object()
            .ok_or_else(|| AppError::BadRequest("Invalid commute breakdown".into()))?;
        if map.len() > 12 {
            return Err(AppError::BadRequest("Too many commute modes".into()));
        }
        for n in map.values() {
            if !n
                .as_f64()
                .is_some_and(|n| n.is_finite() && (0.0..=2000.).contains(&n))
            {
                return Err(AppError::BadRequest("Invalid commute distance".into()));
            }
        }
    }
    Ok(())
}
pub async fn save_baseline(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(r): Json<Baseline>,
) -> AppResult<Json<ApiResponse<Value>>> {
    validate_baseline(&r.profile)?;
    let row:Value=sqlx::query_scalar("INSERT INTO baseline_profiles(user_id,profile,completed) VALUES($1,$2,$3) ON CONFLICT(user_id) DO UPDATE SET profile=EXCLUDED.profile,completed=baseline_profiles.completed OR EXCLUDED.completed,updated_at=NOW() RETURNING to_jsonb(baseline_profiles)").bind(uid(&auth)?).bind(r.profile).bind(r.completed).fetch_one(&state.db).await?;
    Ok(Json(ApiResponse::ok(row)))
}
pub async fn get_baseline(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<Value>>> {
    let row: Option<Value> =
        sqlx::query_scalar("SELECT to_jsonb(b) FROM baseline_profiles b WHERE user_id=$1")
            .bind(uid(&auth)?)
            .fetch_optional(&state.db)
            .await?;
    Ok(Json(ApiResponse::ok(row.unwrap_or(Value::Null))))
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn negative_or_non_numeric_baseline_is_rejected() {
        assert!(validate_baseline(&json!({"dailyCommuteKm":-1})).is_err());
        assert!(validate_baseline(&json!({"commuteDistances":{"walk":"bad"}})).is_err());
        assert!(validate_baseline(
            &json!({"commuteDistances":{"walk":2.75},"monthlyElectricityKwh":0})
        )
        .is_ok());
    }
}
