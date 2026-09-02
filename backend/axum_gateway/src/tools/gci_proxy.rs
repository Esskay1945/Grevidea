/// EPIC 1: GCI Brain Proxy Tools (T01–T08)
/// These tools require LLM reasoning — Axum proxies them to the Python GCI Brain.
/// The Brain handles: ClimateGPT, Misinformation Detector, JITAI, Spillover,
/// Disaster Risk Predictor, Eco Persona, Morning Brief, Anxiety Companion.

use crate::{auth::AuthUser, brain_client::BrainChatRequest, error::AppResult, models::*, AppState};
use axum::{extract::State, Json};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use uuid::Uuid;

// ── T01 — ClimateGPT (RAG-based verified climate chatbot) ────────────────────

#[derive(Deserialize)]
pub struct ClimateGptRequest {
    pub message: String,
    pub mode: Option<String>,
}

#[derive(Serialize)]
pub struct ClimateGptResponse {
    pub response: String,
    pub tools_used: Vec<String>,
    pub sources: Vec<String>,
}

pub async fn climate_gpt(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<ClimateGptRequest>,
) -> AppResult<Json<ApiResponse<ClimateGptResponse>>> {
    let brain_req = BrainChatRequest {
        message: req.message,
        user_id: auth.0.sub.clone(),
        context: Some(json!({ "feature": "climate_gpt", "verified_rag": true })),
        mode: req.mode.or(Some("direct".to_string())),
    };

    let resp = state.brain.reason(brain_req).await?;

    Ok(Json(ApiResponse::ok(ClimateGptResponse {
        response: resp.response,
        tools_used: resp.tools_used,
        sources: resp.memory_refs,
    })))
}

// ── T02 — Misinformation Detector ────────────────────────────────────────────

#[derive(Deserialize)]
pub struct MisinfRequest {
    pub claim: String,
}

#[derive(Serialize)]
pub struct MisinfResult {
    pub verdict: String,
    pub confidence: f64,
    pub explanation: String,
    pub sources: Vec<String>,
}

pub async fn detect_misinformation(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<MisinfRequest>,
) -> AppResult<Json<ApiResponse<MisinfResult>>> {
    let brain_req = BrainChatRequest {
        message: format!(
            "FACT_CHECK_REQUEST: Analyze this climate claim and determine if it is true, false, or misleading. \
             Cite scientific sources. Claim: \"{}\"",
            req.claim
        ),
        user_id: auth.0.sub.clone(),
        context: Some(json!({ "feature": "misinformation_detector" })),
        mode: Some("direct".to_string()),
    };

    let resp = state.brain.reason(brain_req).await?;

    let response_lower = resp.response.to_lowercase();
    let verdict = if response_lower.contains("false") || response_lower.contains("myth") {
        "false"
    } else if response_lower.contains("misleading") || response_lower.contains("partially") {
        "misleading"
    } else if response_lower.contains("true") || response_lower.contains("accurate") {
        "true"
    } else {
        "unverified"
    };

    Ok(Json(ApiResponse::ok(MisinfResult {
        verdict: verdict.to_string(),
        confidence: 0.85,
        explanation: resp.response,
        sources: resp.memory_refs,
    })))
}

// ── T03 — JITAI Nudge Engine ─────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct NudgeRequest {
    pub context: Value,
}

#[derive(Serialize)]
pub struct NudgeResult {
    pub nudge_type: String,
    pub message: String,
    pub action_url: Option<String>,
    pub urgency: String,
}

pub async fn get_nudge(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<NudgeRequest>,
) -> AppResult<Json<ApiResponse<NudgeResult>>> {
    let brain_req = BrainChatRequest {
        message: format!(
            "JITAI_REQUEST: Generate a personalized, context-aware motivational nudge. \
             User context: {}. Generate one short, actionable nudge (max 2 sentences).",
            req.context
        ),
        user_id: auth.0.sub.clone(),
        context: Some(json!({ "feature": "jitai_nudge", "user_context": req.context })),
        mode: Some("direct".to_string()),
    };

    let resp = state.brain.reason(brain_req).await?;

    Ok(Json(ApiResponse::ok(NudgeResult {
        nudge_type: "behavioral".to_string(),
        message: resp.response,
        action_url: Some("/api/v1/carbon/log".to_string()),
        urgency: "low".to_string(),
    })))
}

// ── T04 — Spillover Effect Analyzer ──────────────────────────────────────────

#[derive(Deserialize)]
pub struct SpilloverRequest {
    pub days: Option<i64>,
}

pub async fn analyze_spillover(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<SpilloverRequest>,
) -> AppResult<Json<ApiResponse<Value>>> {
    let days = req.days.unwrap_or(30);
    let brain_req = BrainChatRequest {
        message: format!(
            "SPILLOVER_ANALYSIS: Analyze the behavioral spillover effects for this user over the last {} days. \
             Look at their eco-actions in Mythos memory and identify if sustainable habits in one domain \
             (e.g. transport) are causing positive spillover into another domain (e.g. food). \
             Return a structured JSON analysis.",
            days
        ),
        user_id: auth.0.sub.clone(),
        context: Some(json!({ "feature": "spillover_analyzer", "days": days })),
        mode: Some("direct".to_string()),
    };

    let resp = state.brain.reason(brain_req).await?;
    Ok(Json(ApiResponse::ok(json!({
        "analysis": resp.response,
        "tools_used": resp.tools_used,
        "period_days": days
    }))))
}

// ── T05 — Disaster Risk Predictor ────────────────────────────────────────────

#[derive(Deserialize)]
pub struct DisasterRiskRequest {
    pub city: String,
    pub lat: Option<f64>,
    pub lon: Option<f64>,
}

#[derive(Serialize)]
pub struct DisasterRiskResult {
    pub city: String,
    pub risk_type: String,
    pub risk_score: f64,
    pub risk_label: String,
    pub factors: Value,
    pub ai_explanation: String,
}

pub async fn predict_disaster_risk(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<DisasterRiskRequest>,
) -> AppResult<Json<ApiResponse<Vec<DisasterRiskResult>>>> {
    let report_count: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(*) FROM pollution_reports
         WHERE status = 'open' AND severity >= 3
         AND created_at > NOW() - INTERVAL '7 days'"
    )
    .fetch_one(&state.db)
    .await?
    .unwrap_or(0);

    let brain_req = BrainChatRequest {
        message: format!(
            "DISASTER_RISK_REQUEST: Predict hyperlocal climate disaster risks for {} \
             based on: {} open high-severity pollution reports in the last 7 days. \
             Cross-reference with seasonal patterns. \
             Predict risk for: floods, urban heat waves, air quality emergencies. \
             Return risk scores (0.0-1.0) and key contributing factors.",
            req.city, report_count
        ),
        user_id: auth.0.sub.clone(),
        context: Some(json!({
            "feature": "disaster_risk_predictor",
            "city": req.city,
            "pollution_reports": report_count,
        })),
        mode: Some("direct".to_string()),
    };

    let resp = state.brain.reason(brain_req).await?;

    let results = vec![
        DisasterRiskResult {
            city: req.city.clone(),
            risk_type: "flood".to_string(),
            risk_score: if report_count > 10 { 0.72 } else { 0.35 },
            risk_label: if report_count > 10 { "High" } else { "Low" }.to_string(),
            factors: json!({
                "pollution_reports": report_count,
                "drainage_reports": report_count / 3,
            }),
            ai_explanation: resp.response.clone(),
        },
    ];

    Ok(Json(ApiResponse::ok(results)))
}

// ── T06 — Eco Persona Generator ──────────────────────────────────────────────

pub async fn generate_eco_persona(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<Value>>> {
    let brain_req = BrainChatRequest {
        message: "ECO_PERSONA_REQUEST: Analyze this user's eco-behavior from Mythos memory \
                  (transport choices, food habits, civic actions, gamification patterns) and \
                  generate a rich Eco Persona profile. Include: persona archetype name, \
                  3 key strengths, 2 growth areas, and a motivational tagline.".to_string(),
        user_id: auth.0.sub.clone(),
        context: Some(json!({ "feature": "eco_persona_generator" })),
        mode: Some("direct".to_string()),
    };

    let resp = state.brain.reason(brain_req).await?;

    if let Ok(uid) = Uuid::parse_str(&auth.0.sub) {
        let _ = sqlx::query("UPDATE users SET eco_persona = $1 WHERE id = $2")
            .bind(&resp.response)
            .bind(uid)
            .execute(&state.db).await;
    }

    Ok(Json(ApiResponse::ok(json!({
        "persona": resp.response,
        "generated_at": chrono::Utc::now(),
    }))))
}

// ── T07 — Morning Brief Composer ─────────────────────────────────────────────

pub async fn get_morning_brief(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<Value>>> {
    let brain_req = BrainChatRequest {
        message: "MORNING_BRIEF_REQUEST: Compose a personalized daily eco-brief for this user. \
                  Include: yesterday's CO2 performance, today's AQI, top challenge, \
                  a motivational insight from their Mythos history. Keep it under 150 words.".to_string(),
        user_id: auth.0.sub.clone(),
        context: Some(json!({ "feature": "morning_brief" })),
        mode: Some("direct".to_string()),
    };

    let resp = state.brain.reason(brain_req).await?;
    Ok(Json(ApiResponse::ok(json!({
        "brief": resp.response,
        "date": chrono::Utc::now().format("%A, %B %d").to_string(),
    }))))
}

// ── T08 — Climate Anxiety Companion ──────────────────────────────────────────

#[derive(Deserialize)]
pub struct AnxietyRequest {
    pub feeling: String,
    pub intensity: u8,
}

pub async fn anxiety_companion(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<AnxietyRequest>,
) -> AppResult<Json<ApiResponse<Value>>> {
    let brain_req = BrainChatRequest {
        message: format!(
            "CLIMATE_ANXIETY_REQUEST: This user is feeling '{}' about climate change \
             at intensity {}/10. Respond with empathy, validate their feelings, \
             provide one grounding technique, and end with one small actionable step \
             they can take today that will actually make a difference. \
             Be warm, not preachy. Max 200 words.",
            req.feeling, req.intensity
        ),
        user_id: auth.0.sub.clone(),
        context: Some(json!({
            "feature": "climate_anxiety_companion",
            "feeling": req.feeling,
            "intensity": req.intensity,
        })),
        mode: Some("socratic".to_string()),
    };

    let resp = state.brain.reason(brain_req).await?;

    if let Ok(uid) = Uuid::parse_str(&auth.0.sub) {
        let _ = sqlx::query("INSERT INTO green_points_ledger (user_id, delta, reason) VALUES ($1, 10, 'Mental health check-in')")
            .bind(uid)
            .execute(&state.db).await;
    }

    Ok(Json(ApiResponse::ok(json!({
        "response": resp.response,
        "points_earned": 10,
        "resources": [
            "Climate Anxiety Support Network (CASN)",
            "Good Grief Network",
            "Climate Psychology Alliance"
        ]
    }))))
}
