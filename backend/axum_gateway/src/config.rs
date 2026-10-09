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
    // SMTP for direct civic email dispatch
    pub smtp_host: Option<String>,
    pub smtp_port: u16,
    pub smtp_username: Option<String>,
    pub smtp_password: Option<String>,
    pub smtp_from_email: String,
    pub smtp_from_name: String,
    pub civic_grievance_email: String,
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
            smtp_host: env::var("SMTP_HOST").ok(),
            smtp_port: env::var("SMTP_PORT").ok().and_then(|p| p.parse().ok()).unwrap_or(587),
            smtp_username: env::var("SMTP_USERNAME").ok(),
            smtp_password: env::var("SMTP_PASSWORD").ok(),
            smtp_from_email: env::var("SMTP_FROM_EMAIL").unwrap_or_else(|_| "noreply@grevidea.app".to_string()),
            smtp_from_name: env::var("SMTP_FROM_NAME").unwrap_or_else(|_| "Grevidea Civic Platform".to_string()),
            civic_grievance_email: env::var("CIVIC_GRIEVANCE_EMAIL").unwrap_or_else(|_| "mc@thanecity.gov.in".to_string()),
        }
    }
}
