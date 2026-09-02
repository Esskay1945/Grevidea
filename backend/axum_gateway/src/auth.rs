use crate::{config::Config, error::AppError};
use axum::{
    extract::{FromRef, FromRequestParts},
    http::request::Parts,
};
use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use std::sync::Arc;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    pub sub: String,    // user_id (UUID)
    pub email: String,
    pub role: String,   // "user" | "admin"
    pub iat: i64,
    pub exp: i64,
}

impl Claims {
    pub fn new(user_id: Uuid, email: &str, role: &str, secret: &str) -> Result<String, AppError> {
        let now = Utc::now();
        let exp = now + Duration::days(30);
        let claims = Claims {
            sub: user_id.to_string(),
            email: email.to_string(),
            role: role.to_string(),
            iat: now.timestamp(),
            exp: exp.timestamp(),
        };
        encode(
            &Header::default(),
            &claims,
            &EncodingKey::from_secret(secret.as_bytes()),
        )
        .map_err(|e| AppError::Internal(format!("JWT encode error: {e}")))
    }

    pub fn verify(token: &str, secret: &str) -> Result<Claims, AppError> {
        let data = decode::<Claims>(
            token,
            &DecodingKey::from_secret(secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|e| AppError::Auth(format!("Invalid token: {e}")))?;
        Ok(data.claims)
    }
}

/// Axum extractor — extracts validated Claims from Authorization header
#[derive(Clone)]
pub struct AuthUser(pub Claims);

#[axum::async_trait]
impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
    Arc<Config>: axum::extract::FromRef<S>,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let config = Arc::<Config>::from_ref(state);
        let auth_header = parts
            .headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| AppError::Auth("Missing Authorization header".into()))?;

        let token = auth_header
            .strip_prefix("Bearer ")
            .ok_or_else(|| AppError::Auth("Authorization header must start with 'Bearer '".into()))?;

        let claims = Claims::verify(token, &config.jwt_secret)?;
        Ok(AuthUser(claims))
    }
}

/// Hash a password with bcrypt
pub fn hash_password(password: &str) -> Result<String, AppError> {
    bcrypt::hash(password, 12)
        .map_err(|e| AppError::Internal(format!("Hash error: {e}")))
}

/// Verify password against hash
pub fn verify_password(password: &str, hash: &str) -> Result<bool, AppError> {
    bcrypt::verify(password, hash)
        .map_err(|e| AppError::Internal(format!("Verify error: {e}")))
}
