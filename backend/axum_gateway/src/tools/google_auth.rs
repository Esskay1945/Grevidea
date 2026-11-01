//! Google ID tokens are verified locally using Google's pinned JWKS endpoint.
use axum::{extract::State, Json};
use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey, Validation};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::{sync::OnceLock, time::{Duration, Instant}};
use tokio::sync::Mutex;
use uuid::Uuid;
use crate::{auth::{self, AuthUser, Claims}, error::{AppError, AppResult}, models::ApiResponse, AppState};

#[derive(Deserialize)]
pub struct GoogleRequest { id_token: String }
#[derive(Clone, Deserialize)]
struct Jwk { kid: String, kty: String, n: String, e: String, alg: Option<String> }
#[derive(Clone, Deserialize)]
struct Jwks { keys: Vec<Jwk> }
struct KeyCache { keys: Jwks, expires: Instant, fetched: Instant }
static KEYS: OnceLock<Mutex<Option<KeyCache>>> = OnceLock::new();
#[derive(Debug, Deserialize, Serialize)]
struct GoogleClaims {
    sub: String, email: String, email_verified: bool,
    #[serde(default)] name: String,
    iss: String, aud: String, exp: u64,
}
fn rejected() -> AppError { AppError::Auth("Google credentials could not be verified".into()) }
fn validate_identity(c: &GoogleClaims) -> AppResult<()> {
    if !c.email_verified || c.sub.is_empty() || c.sub.len() > 255 || c.email.len() > 254 ||
        c.email.contains(char::is_whitespace) || !c.email.split_once('@').is_some_and(|(a,b)| !a.is_empty() && b.contains('.') && !b.contains('@')) {
        return Err(rejected());
    }
    Ok(())
}
fn verify_with_key(token: &str, key: &Jwk, audience: &str) -> AppResult<GoogleClaims> {
    if key.kty != "RSA" || key.alg.as_deref().is_some_and(|a| a != "RS256") { return Err(rejected()); }
    let key = DecodingKey::from_rsa_components(&key.n, &key.e).map_err(|_| rejected())?;
    let mut validation = Validation::new(Algorithm::RS256);
    validation.set_audience(&[audience]);
    validation.set_issuer(&["https://accounts.google.com", "accounts.google.com"]);
    validation.leeway = 0;
    let c = decode::<GoogleClaims>(token, &key, &validation).map_err(|_| rejected())?.claims;
    validate_identity(&c)?;
    Ok(c)
}
async fn verify(state: &AppState, token: &str) -> AppResult<GoogleClaims> {
    let audience = state.config.google_client_id.as_deref().filter(|s| !s.is_empty())
        .ok_or_else(|| AppError::BrainUnavailable("Google sign-in is not configured on this server".into()))?;
    if token.is_empty() || token.len() > 16384 { return Err(rejected()); }
    let header = decode_header(token).map_err(|_| rejected())?;
    if header.alg != Algorithm::RS256 { return Err(rejected()); }
    let kid = header.kid.filter(|k| !k.is_empty() && k.len() <= 256).ok_or_else(rejected)?;
    let mut cache = KEYS.get_or_init(|| Mutex::new(None)).lock().await;
    let now = Instant::now();
    let need_refresh = cache.as_ref().is_none_or(|c| now >= c.expires ||
        (!c.keys.keys.iter().any(|k| k.kid == kid) && now.duration_since(c.fetched) >= Duration::from_secs(30)));
    if need_refresh {
        // No user-controlled key URL or token in query strings/logs.
        let response = state.brain.http.get("https://www.googleapis.com/oauth2/v3/certs")
            .timeout(Duration::from_secs(10)).send().await
            .map_err(|_| AppError::BrainUnavailable("Google key service unavailable; retry shortly".into()))?
            .error_for_status().map_err(|_| AppError::BrainUnavailable("Google key service unavailable; retry shortly".into()))?;
        let ttl = response.headers().get("cache-control").and_then(|v| v.to_str().ok())
            .and_then(|s| s.split(',').find_map(|v| v.trim().strip_prefix("max-age=")?.parse::<u64>().ok()))
            .unwrap_or(300).min(86400);
        let keys: Jwks = response.json().await.map_err(|_| AppError::BrainUnavailable("Invalid Google key response".into()))?;
        *cache = Some(KeyCache { keys, expires: now + Duration::from_secs(ttl), fetched: now });
    }
    let key = cache.as_ref().and_then(|c| c.keys.keys.iter().find(|k| k.kid == kid)).cloned().ok_or_else(rejected)?;
    drop(cache);
    verify_with_key(token, &key, audience)
}
#[derive(sqlx::FromRow)]
struct Account { id: Uuid, email: String, display_name: String, role: String }
async fn respond(state: &AppState, account: Account) -> AppResult<Json<ApiResponse<serde_json::Value>>> {
    let token = Claims::new(account.id, &account.email, &account.role, &state.config.jwt_secret)?;
    Ok(Json(ApiResponse::ok(json!({ "token": token, "user_id": account.id, "email": account.email,
        "display_name": account.display_name, "role": account.role }))))
}
/// Public client ID is configuration, never a client secret. Lets installed APKs
/// use the gateway's audience without baking project values into CI artifacts.
pub async fn configuration(State(state): State<AppState>) -> AppResult<Json<ApiResponse<serde_json::Value>>> {
    let schema_ready: bool = sqlx::query_scalar("SELECT COUNT(*) = 2 FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name IN ('google_sub','password_changed_at')")
        .fetch_one(&state.db).await?;
    let client_id = state.config.google_client_id.as_deref().filter(|v| !v.is_empty());
    Ok(Json(ApiResponse::ok(json!({"google_client_id":client_id, "google_configured":client_id.is_some(), "google_database_ready":schema_ready}))))
}

pub async fn google_auth(State(state): State<AppState>, Json(req): Json<GoogleRequest>) -> AppResult<Json<ApiResponse<serde_json::Value>>> {
    let c = verify(&state, &req.id_token).await?;
    let email = c.email.trim().to_lowercase();
    let mut tx = state.db.begin().await?;
    sqlx::query("SELECT pg_advisory_xact_lock(hashtext($1))").bind(format!("google:{email}")).execute(&mut *tx).await?;
    let existing = sqlx::query_as::<_, Account>("SELECT id, email, display_name, role FROM users WHERE google_sub = $1")
        .bind(&c.sub).fetch_optional(&mut *tx).await?;
    let account = if let Some(account) = existing { account } else {
        let taken: bool = sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM users WHERE LOWER(email) = $1)")
            .bind(&email).fetch_one(&mut *tx).await?;
        if taken { return Err(AppError::Forbidden("An account already uses this email. Sign in with your password and link Google from Profile.".into())); }
        let random_password = Uuid::new_v4().to_string();
        let hash = tokio::task::spawn_blocking(move || auth::hash_password(&random_password)).await
            .map_err(|_| AppError::Internal("Account creation unavailable".into()))??;
        let name = if c.name.trim().is_empty() { email.split('@').next().unwrap_or("User").to_string() } else { c.name.chars().take(100).collect() };
        let account = sqlx::query_as::<_, Account>("INSERT INTO users (email, password_hash, display_name, google_sub) VALUES ($1,$2,$3,$4) RETURNING id,email,display_name,role")
            .bind(&email).bind(hash).bind(name).bind(&c.sub).fetch_one(&mut *tx).await?;
        sqlx::query("INSERT INTO streaks(user_id) VALUES ($1)").bind(account.id).execute(&mut *tx).await?;
        sqlx::query("INSERT INTO green_points_ledger(user_id,delta,reason) VALUES ($1,50,'Welcome to Grevidea!')").bind(account.id).execute(&mut *tx).await?;
        account
    };
    tx.commit().await?;
    respond(&state, account).await
}
pub async fn link_google(State(state): State<AppState>, auth: AuthUser, Json(req): Json<GoogleRequest>) -> AppResult<Json<ApiResponse<serde_json::Value>>> {
    let c = verify(&state, &req.id_token).await?;
    let email = c.email.trim().to_lowercase();
    // Linking requires control of both the app session and the Google identity.
    let result = sqlx::query("UPDATE users SET google_sub=$1 WHERE id::text=$2 AND LOWER(email)=$3 AND (google_sub IS NULL OR google_sub=$1) AND NOT EXISTS(SELECT 1 FROM users WHERE google_sub=$1 AND id::text<>$2)")
        .bind(&c.sub).bind(&auth.0.sub).bind(email).execute(&state.db).await?;
    if result.rows_affected() != 1 { return Err(AppError::Forbidden("Use the Google account matching your profile email; this identity must not be linked to another account".into())); }
    Ok(Json(ApiResponse::ok(json!({"linked":true}))))
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn signed_tokens_require_signature_audience_issuer_expiry_and_verified_email() {
        let fixture: serde_json::Value = serde_json::from_str(include_str!("../../tests/google_tokens.json")).unwrap();
        let key: Jwk = serde_json::from_value(fixture["key"].clone()).unwrap();
        let token = fixture["valid"].as_str().unwrap();
        assert!(verify_with_key(token, &key, "synthetic-client").is_ok());
        for field in ["wrong_audience","wrong_issuer","expired","unverified"] {
            assert!(verify_with_key(fixture[field].as_str().unwrap(), &key, "synthetic-client").is_err(), "{field}");
        }
        let (unsigned, signature) = token.rsplit_once('.').unwrap();
        let corrupt = format!("{unsigned}.{}{}", if signature.starts_with('A') { "B" } else { "A" }, &signature[1..]);
        assert!(verify_with_key(&corrupt, &key, "synthetic-client").is_err());
    }
    #[test] fn unverified_or_empty_identity_is_rejected() {
        let mut c = GoogleClaims { sub:"subject".into(), email:"test@example.test".into(), email_verified:true, name:"Test".into(), iss:"https://accounts.google.com".into(), aud:"test-client".into(), exp:4102444800 };
        assert!(validate_identity(&c).is_ok());
        c.email_verified=false; assert!(validate_identity(&c).is_err());
        c.email_verified=true; c.sub.clear(); assert!(validate_identity(&c).is_err());
    }
}
