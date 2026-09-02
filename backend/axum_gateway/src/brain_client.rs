/// GCI Brain HTTP Client
/// The Axum gateway calls the Python Brain when LLM reasoning is needed.
/// For deterministic tools, Axum handles them directly without hitting the Brain.

use crate::{config::Config, error::AppError};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tracing::{info, warn};

#[derive(Debug, Clone, Serialize)]
pub struct BrainChatRequest {
    pub message: String,
    pub user_id: String,
    pub context: Option<Value>,
    pub mode: Option<String>, // "direct" | "socratic"
}

#[derive(Debug, Deserialize)]
pub struct BrainChatResponse {
    pub response: String,
    pub tools_used: Vec<String>,
    pub memory_refs: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct BrainEventRequest {
    pub event_type: String,
    pub source: String,
    pub data: Value,
    pub severity: String,
    pub user_id: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct BrainToolResponse {
    pub success: bool,
    pub result: Value,
    pub tool_name: String,
    pub duration_ms: f64,
}

#[derive(Clone)]
pub struct BrainClient {
    pub http: Client,
    pub base_url: String,
}

impl BrainClient {
    pub fn new(config: &Config) -> Self {
        Self {
            http: Client::builder()
                .timeout(std::time::Duration::from_secs(30))
                .build()
                .expect("Failed to build HTTP client"),
            base_url: config.brain_url.clone(),
        }
    }

    /// Ask the Brain for LLM reasoning — only for non-deterministic features
    pub async fn reason(&self, req: BrainChatRequest) -> Result<BrainChatResponse, AppError> {
        info!("Calling Brain /brain/chat for user: {}", req.user_id);
        self.http
            .post(format!("{}/brain/chat", self.base_url))
            .json(&req)
            .send()
            .await
            .map_err(|e| AppError::BrainUnavailable(e.to_string()))?
            .json::<BrainChatResponse>()
            .await
            .map_err(|e| AppError::BrainUnavailable(format!("Parse error: {e}")))
    }

    /// Log an event into Brain Mythos memory (fire-and-forget, non-blocking)
    pub async fn log_event(&self, event_type: &str, user_id: Option<&str>, data: Value) {
        let req = BrainEventRequest {
            event_type: event_type.to_string(),
            source: "axum_gateway".to_string(),
            data,
            severity: "info".to_string(),
            user_id: user_id.map(|s| s.to_string()),
        };
        if let Err(e) = self.http
            .post(format!("{}/brain/event", self.base_url))
            .json(&req)
            .send()
            .await
        {
            warn!("Brain event log failed (non-critical): {e}");
        }
    }

    /// Get the Brain system status
    pub async fn status(&self) -> Result<Value, AppError> {
        self.http
            .get(format!("{}/brain/status", self.base_url))
            .send()
            .await
            .map_err(|e| AppError::BrainUnavailable(e.to_string()))?
            .json::<Value>()
            .await
            .map_err(|e| AppError::BrainUnavailable(e.to_string()))
    }
}
