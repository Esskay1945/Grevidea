//! Durable, leased provider handoff. Acceptance is not proof of physical delivery.
use crate::{
    auth::AuthUser,
    error::{AppError, AppResult},
    models::ApiResponse,
    AppState,
};
use axum::{
    body::Bytes,
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use chrono::Utc;
use hmac::{Hmac, Mac};
use serde::Deserialize;
use serde_json::{json, Value};
use sha2::Sha256;
use uuid::Uuid;
fn uid(auth: &AuthUser) -> AppResult<Uuid> {
    Uuid::parse_str(&auth.0.sub).map_err(|_| AppError::Auth("Invalid account".into()))
}
pub async fn enqueue(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    user: Uuid,
    entity: Uuid,
    kind: &str,
    payload: Value,
) -> AppResult<Uuid> {
    let id=sqlx::query_scalar("INSERT INTO delivery_jobs(user_id,entity_id,kind,payload) VALUES($1,$2,$3,$4) ON CONFLICT(kind,entity_id) DO UPDATE SET entity_id=EXCLUDED.entity_id RETURNING id").bind(user).bind(entity).bind(kind).bind(payload).fetch_one(&mut **tx).await?;
    Ok(id)
}
pub fn provider(kind: &str) -> Option<(String, String)> {
    let prefix = match kind {
        "sos" => "SOS",
        "civic" => "MUNICIPAL",
        "reward" => "FULFILLMENT",
        _ => return None,
    };
    let url = std::env::var(format!("{prefix}_RELAY_URL")).ok()?;
    let token = std::env::var(format!("{prefix}_RELAY_TOKEN")).ok()?;
    if token.is_empty()
        || !url.starts_with("https://")
            && !(std::env::var("ALLOW_LOCAL_TEST_PROVIDERS").as_deref() == Ok("true")
                && url.starts_with("http://127.0.0.1:"))
    {
        return None;
    }
    Some((url, token))
}
pub fn backoff(attempt: i32) -> i64 {
    (5_i64 * 2_i64.pow(attempt.clamp(0, 10) as u32)).min(3600)
}
pub async fn run_worker(state: AppState) {
    loop {
        if let Err(_) = process_next(&state).await {
            tracing::warn!("Provider delivery worker failed; durable queue will retry");
        }
        tokio::time::sleep(std::time::Duration::from_secs(2)).await;
    }
}
async fn process_next(state: &AppState) -> AppResult<()> {
    let mut tx = state.db.begin().await?;
    let row:Option<(Uuid,Uuid,Uuid,String,Value,i32)>=sqlx::query_as("SELECT id,user_id,entity_id,kind,payload,attempts FROM delivery_jobs WHERE ((status IN ('queued','blocked','failed') AND next_attempt_at<=NOW()) OR (status='processing' AND lease_until<NOW())) ORDER BY CASE WHEN kind='sos' THEN 0 ELSE 1 END,created_at FOR UPDATE SKIP LOCKED LIMIT 1").fetch_optional(&mut *tx).await?;
    let Some((id, user, entity, kind, mut payload, attempts)) = row else {
        return Ok(());
    };
    let Some((url, token)) = provider(&kind) else {
        sqlx::query("UPDATE delivery_jobs SET status='blocked',last_error='Provider not configured',next_attempt_at=NOW()+INTERVAL '30 seconds',lease_until=NULL,updated_at=NOW() WHERE id=$1").bind(id).execute(&mut *tx).await?;
        tx.commit().await?;
        return Ok(());
    };
    sqlx::query("UPDATE delivery_jobs SET status='processing',attempts=attempts+1,lease_until=NOW()+INTERVAL '60 seconds',updated_at=NOW() WHERE id=$1").bind(id).execute(&mut *tx).await?;
    tx.commit().await?;
    if kind == "sos" {
        let contacts:Vec<Value>=sqlx::query_scalar("SELECT jsonb_build_object('name',name,'phone',phone,'consent_attested',consent_attested) FROM trusted_contacts WHERE user_id=$1 AND consent_attested=TRUE").bind(user).fetch_all(&state.db).await?;
        payload["trusted_contacts"] = json!(contacts);
    }
    let body = json!({"schema_version":1,"delivery_id":id,"entity_id":entity,"kind":kind,"payload":payload});
    let response = state
        .brain
        .http
        .post(url)
        .bearer_auth(token)
        .header("Idempotency-Key", id.to_string())
        .header("User-Agent", "Grevidea/1.0")
        .json(&body)
        .timeout(std::time::Duration::from_secs(20))
        .send()
        .await;
    let accepted = match response {
        Ok(r) if r.status().is_success() => r.json::<Value>().await.ok().filter(|v| {
            v["provider_id"]
                .as_str()
                .is_some_and(|s| !s.is_empty() && s.len() <= 200)
        }),
        _ => None,
    };
    if let Some(receipt) = accepted {
        // Do not regress a concurrently received delivered callback.
        sqlx::query("UPDATE delivery_jobs SET status='accepted',provider_id=$2,receipt=$3,last_error=NULL,lease_until=NULL,updated_at=NOW() WHERE id=$1 AND status='processing'").bind(id).bind(receipt["provider_id"].as_str().map(str::to_owned)).bind(receipt).execute(&state.db).await?;
    } else {
        let status = if attempts + 1 >= 8 {
            "dead_letter"
        } else {
            "failed"
        };
        sqlx::query("UPDATE delivery_jobs SET status=$2,last_error='Provider handoff failed or receipt invalid',next_attempt_at=NOW()+make_interval(secs=>$3::double precision),lease_until=NULL,updated_at=NOW() WHERE id=$1 AND status='processing'").bind(id).bind(status).bind(backoff(attempts+1) as f64).execute(&state.db).await?;
    }
    Ok(())
}
pub async fn list(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<Value>>> {
    let rows:Vec<Value>=sqlx::query_scalar("SELECT jsonb_build_object('id',id,'entity_id',entity_id,'kind',kind,'status',status,'attempts',attempts,'provider_id',provider_id,'last_error',last_error,'receipt',receipt,'updated_at',updated_at) FROM delivery_jobs WHERE user_id=$1 ORDER BY created_at DESC LIMIT 100").bind(uid(&auth)?).fetch_all(&state.db).await?;
    Ok(Json(ApiResponse::ok(json!(rows))))
}
pub async fn retry(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(id): Path<Uuid>,
) -> AppResult<Json<ApiResponse<Value>>> {
    let changed=sqlx::query("UPDATE delivery_jobs SET status='queued',attempts=0,next_attempt_at=NOW(),last_error=NULL,updated_at=NOW() WHERE id=$1 AND user_id=$2 AND status IN ('blocked','failed','dead_letter')").bind(id).bind(uid(&auth)?).execute(&state.db).await?.rows_affected();
    if changed != 1 {
        return Err(AppError::BadRequest(
            "Delivery cannot be retried or is not yours".into(),
        ));
    }
    Ok(Json(ApiResponse::ok(json!({"id":id,"status":"queued"}))))
}
#[derive(Deserialize)]
pub struct Contact {
    pub name: String,
    pub phone: String,
    pub consent_attested: bool,
}
pub fn valid_phone(phone: &str) -> bool {
    phone.starts_with('+')
        && (9..=16).contains(&phone.len())
        && phone[1..].chars().all(|c| c.is_ascii_digit())
}
pub async fn save_contact(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(r): Json<Contact>,
) -> AppResult<Json<ApiResponse<Value>>> {
    if !r.consent_attested
        || r.name.trim().is_empty()
        || r.name.len() > 100
        || !valid_phone(&r.phone)
    {
        return Err(AppError::BadRequest(
            "Name, E.164 phone and contact consent are required".into(),
        ));
    }
    let id:Uuid=sqlx::query_scalar("INSERT INTO trusted_contacts(user_id,name,phone,consent_attested) VALUES($1,$2,$3,TRUE) ON CONFLICT(user_id,phone) DO UPDATE SET name=EXCLUDED.name RETURNING id").bind(uid(&auth)?).bind(r.name.trim()).bind(r.phone).fetch_one(&state.db).await?;
    Ok(Json(ApiResponse::ok(
        json!({"id":id,"consent_attested":true}),
    )))
}
pub async fn contacts(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<Value>>> {
    let rows: Vec<Value> = sqlx::query_scalar(
        "SELECT to_jsonb(c)-'user_id' FROM trusted_contacts c WHERE user_id=$1 ORDER BY created_at",
    )
    .bind(uid(&auth)?)
    .fetch_all(&state.db)
    .await?;
    Ok(Json(ApiResponse::ok(json!(rows))))
}
pub async fn delete_contact(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(id): Path<Uuid>,
) -> AppResult<Json<ApiResponse<Value>>> {
    sqlx::query("DELETE FROM trusted_contacts WHERE id=$1 AND user_id=$2")
        .bind(id)
        .bind(uid(&auth)?)
        .execute(&state.db)
        .await?;
    Ok(Json(ApiResponse::ok(json!({"removed":true}))))
}
pub fn verify_signature(
    secret: &str,
    timestamp: &str,
    signature: &str,
    body: &[u8],
    now: i64,
) -> bool {
    let Ok(time) = timestamp.parse::<i64>() else {
        return false;
    };
    if now.abs_diff(time) > 300 || secret.is_empty() {
        return false;
    }
    let Ok(bytes) = hex::decode(signature) else {
        return false;
    };
    let Ok(mut mac) = Hmac::<Sha256>::new_from_slice(secret.as_bytes()) else {
        return false;
    };
    mac.update(timestamp.as_bytes());
    mac.update(b".");
    mac.update(body);
    mac.verify_slice(&bytes).is_ok()
}
#[derive(Deserialize)]
struct Receipt {
    event_id: String,
    delivery_id: Uuid,
    provider_id: String,
    status: String,
    details: Option<Value>,
}
pub async fn callback(
    State(state): State<AppState>,
    headers: HeaderMap,
    body: Bytes,
) -> AppResult<Json<ApiResponse<Value>>> {
    let secret = std::env::var("DELIVERY_CALLBACK_SECRET").unwrap_or_default();
    let timestamp = headers
        .get("x-grevidea-timestamp")
        .and_then(|h| h.to_str().ok())
        .unwrap_or("");
    let signature = headers
        .get("x-grevidea-signature")
        .and_then(|h| h.to_str().ok())
        .unwrap_or("");
    if body.len() > 64000
        || !verify_signature(&secret, timestamp, signature, &body, Utc::now().timestamp())
    {
        return Err(AppError::Auth(
            "Invalid or expired provider signature".into(),
        ));
    }
    let r: Receipt = serde_json::from_slice(&body)
        .map_err(|_| AppError::BadRequest("Invalid receipt".into()))?;
    if r.event_id.is_empty()
        || r.event_id.len() > 200
        || r.provider_id.is_empty()
        || r.provider_id.len() > 200
        || !["delivered", "failed"].contains(&r.status.as_str())
    {
        return Err(AppError::BadRequest(
            "Invalid receipt status/identifier".into(),
        ));
    }
    let mut tx = state.db.begin().await?;
    let row: Option<(String, Option<String>, String, Uuid)> = sqlx::query_as(
        "SELECT status,provider_id,kind,entity_id FROM delivery_jobs WHERE id=$1 FOR UPDATE",
    )
    .bind(r.delivery_id)
    .fetch_optional(&mut *tx)
    .await?;
    let Some((status, provider_id, kind, entity)) = row else {
        return Err(AppError::NotFound("Delivery not found".into()));
    };
    if provider_id.as_ref().is_some_and(|p| p != &r.provider_id) {
        return Err(AppError::BadRequest("Receipt provider mismatch".into()));
    }
    if !["processing", "accepted", "delivered", "failed"].contains(&status.as_str()) {
        return Err(AppError::BadRequest(
            "No provider handoff exists for this delivery".into(),
        ));
    }
    let inserted = sqlx::query(
        "INSERT INTO provider_receipts(id,delivery_id) VALUES($1,$2) ON CONFLICT DO NOTHING",
    )
    .bind(r.event_id)
    .bind(r.delivery_id)
    .execute(&mut *tx)
    .await?
    .rows_affected();
    if inserted == 1 && status != "delivered" {
        sqlx::query("UPDATE delivery_jobs SET status=$2,provider_id=$3,receipt=$4,lease_until=NULL,next_attempt_at=NOW()+INTERVAL '1 minute',updated_at=NOW() WHERE id=$1").bind(r.delivery_id).bind(&r.status).bind(r.provider_id).bind(json!({"status":r.status,"details":r.details})).execute(&mut *tx).await?;
        if kind == "reward" && r.status == "delivered" {
            sqlx::query("UPDATE reward_redemptions SET status='fulfilled' WHERE id=$1")
                .bind(entity)
                .execute(&mut *tx)
                .await?;
        }
    }
    tx.commit().await?;
    Ok(Json(ApiResponse::ok(
        json!({"received":true,"duplicate":inserted==0}),
    )))
}
pub async fn readiness(
    State(_state): State<AppState>,
    _auth: AuthUser,
) -> Json<ApiResponse<Value>> {
    Json(ApiResponse::ok(
        json!({"sos_configured":provider("sos").is_some(),"municipal_configured":provider("civic").is_some(),"fulfillment_configured":provider("reward").is_some(),"callback_configured":std::env::var("DELIVERY_CALLBACK_SECRET").is_ok_and(|s|!s.is_empty()),"hazard_feed_configured":std::env::var("HAZARD_FEED_URL").is_ok_and(|s|s.starts_with("https://"))}),
    ))
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn backoff_is_bounded() {
        assert_eq!(backoff(1), 10);
        assert_eq!(backoff(100), 3600);
    }
    #[test]
    fn e164_is_required() {
        assert!(valid_phone("+919876543210"));
        assert!(!valid_phone("9876543210"));
        assert!(!valid_phone("+91test12345"));
    }
    #[test]
    fn callback_requires_valid_recent_hmac() {
        let body = b"receipt";
        let timestamp = "1000";
        let mut mac = Hmac::<Sha256>::new_from_slice(b"test-secret").unwrap();
        mac.update(b"1000.receipt");
        let sig = hex::encode(mac.finalize().into_bytes());
        assert!(verify_signature("test-secret", timestamp, &sig, body, 1001));
        assert!(!verify_signature(
            "test-secret",
            timestamp,
            &sig,
            b"changed",
            1001
        ));
        assert!(!verify_signature(
            "test-secret",
            timestamp,
            &sig,
            body,
            1301
        ));
    }
}

pub async fn cancel_reward(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(entity): Path<Uuid>,
) -> AppResult<Json<ApiResponse<Value>>> {
    let user = uid(&auth)?;
    let mut tx = state.db.begin().await?;
    sqlx::query("SELECT id FROM users WHERE id=$1 FOR UPDATE")
        .bind(user)
        .fetch_one(&mut *tx)
        .await?;
    let reward: Option<(i32, String)> = sqlx::query_as(
        "SELECT cost,status FROM reward_redemptions WHERE id=$1 AND user_id=$2 FOR UPDATE",
    )
    .bind(entity)
    .bind(user)
    .fetch_optional(&mut *tx)
    .await?;
    let Some((cost, status)) = reward else {
        return Err(AppError::NotFound("Reward receipt not found".into()));
    };
    if status == "cancelled" {
        return Ok(Json(ApiResponse::ok(
            json!({"cancelled":true,"already_cancelled":true}),
        )));
    }
    if status != "pending_fulfillment" {
        return Err(AppError::BadRequest("Reward already fulfilled".into()));
    }
    let changed=sqlx::query("UPDATE delivery_jobs SET status='cancelled',updated_at=NOW() WHERE entity_id=$1 AND user_id=$2 AND kind='reward' AND status IN ('queued','blocked','failed','dead_letter')").bind(entity).bind(user).execute(&mut *tx).await?.rows_affected();
    if changed != 1 {
        return Err(AppError::BadRequest(
            "Provider handoff has begun; contact the fulfillment partner for cancellation".into(),
        ));
    }
    sqlx::query("UPDATE reward_redemptions SET status='cancelled' WHERE id=$1")
        .bind(entity)
        .execute(&mut *tx)
        .await?;
    sqlx::query("INSERT INTO green_points_ledger(user_id,delta,reason,reference_id) VALUES($1,$2,'Cancelled reward refund',$3)").bind(user).bind(cost).bind(entity).execute(&mut *tx).await?;
    tx.commit().await?;
    Ok(Json(ApiResponse::ok(
        json!({"cancelled":true,"refunded_points":cost}),
    )))
}
