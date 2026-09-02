use dotenvy::dotenv;
use std::env;

#[derive(Clone, Debug)]
pub struct Config {
    pub database_url: String,
    pub brain_url: String,
    pub jwt_secret: String,
    pub port: u16,
    pub cpcb_api_key: Option<String>,
    pub openaq_api_key: Option<String>,
    pub fcm_server_key: Option<String>,
    pub openweather_api_key: String,
}

impl Config {
    pub fn from_env() -> Self {
        dotenv().ok();
        Self {
            database_url: env::var("DATABASE_URL")
                .expect("DATABASE_URL must be set (Supabase connection string)"),
            brain_url: env::var("BRAIN_URL")
                .unwrap_or_else(|_| "http://localhost:8000".to_string()),
            jwt_secret: env::var("JWT_SECRET")
                .unwrap_or_else(|_| "grevidea-dev-secret-change-in-production".to_string()),
            port: env::var("GATEWAY_PORT")
                .unwrap_or_else(|_| "3000".to_string())
                .parse()
                .unwrap_or(3000),
            cpcb_api_key: env::var("CPCB_API_KEY").ok(),
            openaq_api_key: env::var("OPENAQ_API_KEY").ok(),
            fcm_server_key: env::var("FCM_SERVER_KEY").ok(),
            openweather_api_key: env::var("OPENWEATHER_API_KEY").unwrap_or_default(),
        }
    }
}
