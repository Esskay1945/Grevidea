//! Official-feed ingestion and separate model context; absence never means safe.
use super::live::{validate_coordinates, Nearby};
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
use serde_json::{json, Value};
pub fn active_alerts(
    feed: &Value,
    lat: f64,
    lon: f64,
    now: DateTime<Utc>,
) -> AppResult<Vec<Value>> {
    let items = feed
        .as_array()
        .ok_or_else(|| AppError::BrainUnavailable("Hazard feed must be an array".into()))?;
    if items.len() > 1000 {
        return Err(AppError::BrainUnavailable(
            "Hazard feed exceeds supported size".into(),
        ));
    }
    let mut alerts = Vec::new();
    for item in items {
        let Some(bounds) = item["bounds"].as_array().filter(|b| b.len() == 4) else {
            continue;
        };
        let Some(west) = bounds[0].as_f64() else {
            continue;
        };
        let Some(south) = bounds[1].as_f64() else {
            continue;
        };
        let Some(east) = bounds[2].as_f64() else {
            continue;
        };
        let Some(north) = bounds[3].as_f64() else {
            continue;
        };
        if validate_coordinates(south, west).is_err()
            || validate_coordinates(north, east).is_err()
            || south > north
        {
            continue;
        }
        let within_lon = if west <= east {
            west <= lon && lon <= east
        } else {
            lon >= west || lon <= east
        };
        if !within_lon || lat < south || lat > north {
            continue;
        }
        let Some(issued) = item["issued_at"]
            .as_str()
            .and_then(|s| DateTime::parse_from_rfc3339(s).ok())
        else {
            continue;
        };
        let Some(expires) = item["expires_at"]
            .as_str()
            .and_then(|s| DateTime::parse_from_rfc3339(s).ok())
        else {
            continue;
        };
        if issued > now || expires <= now || expires <= issued {
            continue;
        }
        if !["flood", "flash_flood", "heat", "air_quality", "storm"]
            .contains(&item["kind"].as_str().unwrap_or(""))
            || item["id"].as_str().is_none()
            || item["title"].as_str().is_none()
            || !item["source_url"]
                .as_str()
                .is_some_and(|s| s.starts_with("https://"))
        {
            continue;
        }
        alerts.push(item.clone());
    }
    Ok(alerts)
}
pub async fn alerts(
    State(state): State<AppState>,
    _auth: AuthUser,
    Query(q): Query<Nearby>,
) -> AppResult<Json<ApiResponse<Value>>> {
    validate_coordinates(q.lat, q.lon)?;
    let official = async {
        let url = std::env::var("HAZARD_FEED_URL").map_err(|_| {
            AppError::BrainUnavailable("Official hazard feed not configured".into())
        })?;
        if !url.starts_with("https://")
            && !(std::env::var("ALLOW_LOCAL_TEST_PROVIDERS").as_deref() == Ok("true")
                && url.starts_with("http://127.0.0.1:"))
        {
            return Err(AppError::BrainUnavailable(
                "Hazard feed must use HTTPS".into(),
            ));
        }
        let mut request = state
            .brain
            .http
            .get(url)
            .query(&[("lat", q.lat), ("lon", q.lon)])
            .header("User-Agent", "Grevidea/1.0")
            .timeout(std::time::Duration::from_secs(15));
        if let Ok(token) = std::env::var("HAZARD_FEED_TOKEN") {
            request = request.bearer_auth(token);
        }
        let feed: Value = request
            .send()
            .await
            .map_err(|_| AppError::BrainUnavailable("Official feed unavailable".into()))?
            .error_for_status()
            .map_err(|_| AppError::BrainUnavailable("Official feed rejected request".into()))?
            .json()
            .await
            .map_err(|_| AppError::BrainUnavailable("Invalid official feed".into()))?;
        active_alerts(&feed, q.lat, q.lon, Utc::now())
    };
    let parameters = [
        ("latitude", q.lat.to_string()),
        ("longitude", q.lon.to_string()),
        ("daily", "river_discharge".into()),
        ("forecast_days", "3".into()),
    ];
    let flood_url = std::env::var("FLOOD_API_URL")
        .unwrap_or("https://flood-api.open-meteo.com/v1/flood".into());
    let forecast = super::live::fetch(&state, &flood_url, &parameters);
    let (official, forecast) = tokio::join!(official, forecast);
    let (status, alerts) = match official {
        Ok(items) => ("available", items),
        Err(_) => ("unavailable", vec![]),
    };
    Ok(Json(ApiResponse::ok(
        json!({"official_status":status,"alerts":alerts,"source":std::env::var("HAZARD_FEED_NAME").unwrap_or("Configured authority feed".into()),"river_forecast":forecast.ok(),"river_forecast_source":"Open-Meteo / GloFAS river discharge model, 5 km daily resolution; not a flash-flood warning","message":if status=="unavailable" {"Official alerts unavailable; local safety cannot be determined"}else{"Consult the issuing authority for instructions; no matched alerts does not establish safety"}}),
    )))
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn stale_or_outside_alerts_are_excluded() {
        let now = DateTime::parse_from_rfc3339("2026-10-09T01:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let feed = json!([{"id":"one","kind":"flash_flood","title":"Warning","bounds":[72.,19.,74.,20.],"issued_at":"2026-10-09T00:00:00Z","expires_at":"2026-10-09T02:00:00Z","source_url":"https://authority.example/one"}]);
        assert_eq!(active_alerts(&feed, 19.2, 72.9, now).unwrap().len(), 1);
        assert!(active_alerts(&feed, 18., 72.9, now).unwrap().is_empty());
        assert!(
            active_alerts(&feed, 19.2, 72.9, now + chrono::Duration::hours(3))
                .unwrap()
                .is_empty()
        );
    }
}
