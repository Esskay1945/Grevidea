//! Grevidea Gateway — Android-Ready Axum API Server
//!
//! Architecture:
//!   Android App → Axum Gateway (port 3000) → GCI Brain (port 8000)
//!
//! Route namespaces:
//!   /api/v1/*   — Public Android REST API (JWT required for most)
//!   /health     — Health check (public)

mod auth;
mod brain_client;
mod config;
mod error;
mod models;
mod tools;

use axum::{
    http::Method,
    response::Json,
    routing::{delete, get, post, put},
    Router,
};
use brain_client::BrainClient;
use config::Config;
use serde_json::json;
use sqlx::{postgres::PgPoolOptions, PgPool};
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

/// Shared application state — injected into every handler
#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub brain: BrainClient,
    pub config: Arc<Config>,
}

impl axum::extract::FromRef<AppState> for Arc<Config> {
    fn from_ref(state: &AppState) -> Self {
        state.config.clone()
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize structured logging
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| "grevidea_gateway=debug,tower_http=info".into()))
        .with(tracing_subscriber::fmt::layer())
        .init();

    let config = Config::from_env();
    let port = config.port;

    info!("🌿 Grevidea Gateway starting on port {port}");
    info!("🧠 GCI Brain endpoint: {}", config.brain_url);

    // Connect to Supabase PostgreSQL (resilient lazy pool allows startup in dev/test)
    let db = match PgPoolOptions::new()
        .max_connections(20)
        .acquire_timeout(std::time::Duration::from_secs(3))
        .connect(&config.database_url)
        .await
    {
        Ok(pool) => {
            info!("✅ Database connected to PostgreSQL");
            pool
        }
        Err(e) => {
            tracing::warn!("⚠️  Database connection not immediately established: {e}. Running with lazy pool.");
            PgPoolOptions::new()
                .max_connections(20)
                .connect_lazy(&config.database_url)
                .expect("Failed to initialize database pool")
        }
    };

    let brain = BrainClient::new(&config);
    let config = Arc::new(config);

    let state = AppState { db, brain, config };

    // CORS for Android (allow all origins in dev)
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE, Method::OPTIONS])
        .allow_headers(Any);

    let app = Router::new()
        // ── Health ───────────────────────────────────────────────────
        .route("/health", get(health_check))
        .route("/", get(root_info))

        // ── EPIC 6: Auth & User (T49–T54) ────────────────────────────
        .route("/api/v1/auth/register", post(tools::platform::register))
        .route("/api/v1/auth/login",    post(tools::platform::login))
        .route("/api/v1/user/profile",  get(tools::platform::get_profile))
        .route("/api/v1/user/profile",  put(tools::platform::update_profile))
        .route("/api/v1/user/delete",   delete(tools::platform::delete_account))
        .route("/api/v1/user/follow/:target_id",   post(tools::platform::follow_user))
        .route("/api/v1/user/unfollow/:target_id", delete(tools::platform::unfollow_user))

        // ── EPIC 2: Carbon Footprint (T09–T18) ───────────────────────
        .route("/api/v1/carbon/calculate",   post(tools::footprint::carbon_calc))
        .route("/api/v1/carbon/log",         post(tools::footprint::log_carbon_trip))
        .route("/api/v1/carbon/history",     get(tools::footprint::carbon_history))
        .route("/api/v1/carbon/budget",      post(tools::footprint::set_carbon_budget))
        .route("/api/v1/carbon/food",        post(tools::footprint::food_carbon))
        .route("/api/v1/carbon/compare",     get(tools::footprint::carbon_comparison))

        // ── EPIC 4: Civic & AQI (T29–T38) ────────────────────────────
        .route("/api/v1/aqi",                get(tools::civic::get_aqi))
        .route("/api/v1/aqi/route",          post(tools::civic::score_route_aqi))
        .route("/api/v1/green-zones",        get(tools::civic::find_green_zones))
        .route("/api/v1/reports",            post(tools::civic::submit_pollution_report))
        .route("/api/v1/rti/draft",          post(tools::civic::draft_rti))
        .route("/api/v1/sos",                post(tools::civic::create_sos))
        .route("/api/v1/sos/nearby",         get(tools::civic::get_nearby_sos))

        // ── EPIC 5: Gamification (T39–T48) ────────────────────────────
        .route("/api/v1/points",             get(tools::gamification::get_points_balance))
        .route("/api/v1/achievements",       get(tools::gamification::list_achievements))
        .route("/api/v1/achievements/check", post(tools::gamification::check_achievements))
        .route("/api/v1/leaderboard",        get(tools::gamification::get_leaderboard))
        .route("/api/v1/streak",             get(tools::gamification::get_streak))
        .route("/api/v1/squads",             post(tools::gamification::create_squad))
        .route("/api/v1/impact",             post(tools::gamification::translate_impact))
        .route("/api/v1/feed",               get(tools::gamification::get_feed))
        .route("/api/v1/feed",               post(tools::gamification::create_post))
        .route("/api/v1/campaigns",          post(tools::gamification::create_campaign))

        // ── EPIC 3: Marketplace (T19–T28) ─────────────────────────────
        .route("/api/v1/marketplace",          get(tools::marketplace::get_marketplace))
        .route("/api/v1/marketplace",          post(tools::marketplace::list_carbon_credits))
        .route("/api/v1/marketplace/borrow/:listing_id", post(tools::marketplace::request_borrow))
        .route("/api/v1/gigs",                 get(tools::marketplace::get_gigs))
        .route("/api/v1/gigs",                 post(tools::marketplace::post_gig))
        .route("/api/v1/carpool",              get(tools::marketplace::get_carpools))
        .route("/api/v1/carpool",              post(tools::marketplace::post_carpool))

        // ── EPIC 1: GCI Brain Proxy (T01–T08) ─────────────────────────
        .route("/api/v1/ai/chat",              post(tools::gci_proxy::climate_gpt))
        .route("/api/v1/ai/factcheck",         post(tools::gci_proxy::detect_misinformation))
        .route("/api/v1/ai/nudge",             post(tools::gci_proxy::get_nudge))
        .route("/api/v1/ai/spillover",         post(tools::gci_proxy::analyze_spillover))
        .route("/api/v1/ai/disaster-risk",     post(tools::gci_proxy::predict_disaster_risk))
        .route("/api/v1/ai/eco-persona",       post(tools::gci_proxy::generate_eco_persona))
        .route("/api/v1/ai/morning-brief",     get(tools::gci_proxy::get_morning_brief))
        .route("/api/v1/ai/anxiety",           post(tools::gci_proxy::anxiety_companion))

        // ── EPIC 6: Learning (T57) ────────────────────────────────────
        .route("/api/v1/learn/cards",          get(tools::platform::get_daily_cards))
        .route("/api/v1/learn/cards/:card_id/complete", post(tools::platform::complete_card))

        // ── Internal Tool Dispatcher (called by GCI Brain Python proxy) ──
        .route("/internal/tools/:tool_name",   post(tools::internal::dispatch_internal_tool))

        // ── NEW: EPIC 2 Expansion — Telemetry (T10,T14,T15,T16,T17) ──────
        .route("/api/v1/transport/detect",     post(tools::footprint::detect_transport_mode))
        .route("/api/v1/lifestyle/infer",      post(tools::footprint::infer_lifestyle))
        .route("/api/v1/health/correlation",   get(tools::footprint::correlate_health_planet))
        .route("/api/v1/supply-chain/trace",   post(tools::footprint::trace_supply_chain))
        .route("/api/v1/carbon/weekly-report", get(tools::footprint::weekly_carbon_report))

        // ── NEW: EPIC 3 Expansion — Marketplace (T19b,T20,T24,T25,T26,T27,T28) ─
        .route("/api/v1/marketplace/trade",        post(tools::marketplace::execute_trade))
        .route("/api/v1/scan/product",             post(tools::marketplace::scan_product))
        .route("/api/v1/products/alternatives",    post(tools::marketplace::recommend_alternatives))
        .route("/api/v1/marketplace/verify-seller", post(tools::marketplace::verify_seller))
        .route("/api/v1/offsets/suggest",          post(tools::marketplace::suggest_offsets))
        .route("/api/v1/marketplace/impact",       get(tools::marketplace::marketplace_impact))
        .route("/api/v1/marketplace/circular-stats", get(tools::marketplace::circular_economy_stats))

        // ── NEW: EPIC 4 Expansion — Civic (T30,T32,T35,T38) ──────────────
        .route("/api/v1/aqi/heatmap",              get(tools::civic::generate_aqi_heatmap))
        .route("/api/v1/pollution/sources",        get(tools::civic::map_pollution_sources))
        .route("/api/v1/civic/projects",           get(tools::civic::get_municipal_projects))
        .route("/api/v1/civic/vote",               post(tools::civic::vote_for_project))
        .route("/api/v1/health/aqi-impact",        post(tools::civic::explain_health_impact))

        // ── NEW: EPIC 5 Expansion — Gamification (T45) ───────────────────
        .route("/api/v1/challenges",               get(tools::gamification::generate_daily_challenges))
        .route("/api/v1/challenges/:challenge_id/complete", post(tools::gamification::complete_challenge))

        // ── NEW: EPIC 6 Expansion — Platform (T51,T52,T55,T56,T58) ───────
        .route("/api/v1/user/behavior",            get(tools::platform::analyze_behavior))
        .route("/api/v1/analytics/anomaly",        post(tools::platform::explain_anomaly))
        .route("/api/v1/notifications/send",       post(tools::platform::send_notification))
        .route("/api/v1/nudge/schedule",           post(tools::platform::schedule_nudge))
        .route("/api/v1/nudge/schedules",          get(tools::platform::get_nudge_schedules))
        .route("/api/v1/admin/override",           post(tools::platform::admin_override))

        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}"))
        .await?;

    info!("🚀 Grevidea Gateway live at http://0.0.0.0:{port}");
    info!("📱 Android endpoints: http://0.0.0.0:{port}/api/v1/*");
    info!("💚 Health: http://0.0.0.0:{port}/health");

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> Json<serde_json::Value> {
    Json(json!({
        "status": "healthy",
        "service": "grevidea-gateway",
        "version": "0.1.0",
        "timestamp": chrono::Utc::now().to_rfc3339(),
    }))
}

async fn root_info() -> Json<serde_json::Value> {
    Json(json!({
        "name": "Grevidea API Gateway",
        "description": "58 features for sustainable living, powered by GCI Brain",
        "docs": "/api/v1",
        "health": "/health",
        "android_sdk": "Use Authorization: Bearer <token> header for all /api/v1/* endpoints",
        "features": {
            "gci_brain":      "AI chat, fact-check, nudges, disaster risk, eco persona",
            "carbon":         "Calculate, log, budget, food, history, comparison",
            "civic":          "AQI, pollution reports, RTI, disaster SOS, green zones",
            "gamification":   "Points, achievements, streaks, squads, leaderboard",
            "marketplace":    "Carbon credits, borrow/lend, carpool, gig economy",
            "social":         "Feed, posts, follow, crowdfunding",
            "learning":       "Daily climate cards, micro-learning",
        }
    }))
}
