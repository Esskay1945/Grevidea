use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ─── Common Response Wrapper ─────────────────────────────────────────────────

#[derive(Serialize)]
pub struct ApiResponse<T: Serialize> {
    pub success: bool,
    pub data: T,
    pub message: Option<String>,
}

impl<T: Serialize> ApiResponse<T> {
    pub fn ok(data: T) -> Self {
        Self { success: true, data, message: None }
    }
    pub fn with_message(data: T, msg: &str) -> Self {
        Self { success: true, data, message: Some(msg.to_string()) }
    }
}

// ─── Auth / User ──────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow, Clone)]
pub struct User {
    pub id: Uuid,
    pub email: String,
    pub display_name: String,
    pub role: String,
    pub eco_persona: Option<String>,
    pub fcm_token: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub display_name: String,
}

#[derive(Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Serialize)]
pub struct AuthResponse {
    pub token: String,
    pub user_id: String,
    pub display_name: String,
    pub role: String,
}

// ─── Carbon / Footprint ───────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct CarbonCalcRequest {
    pub mode: String,        // "car" | "bus" | "train" | "cycle" | "walk" | "flight" | "motorbike"
    pub distance_km: f64,
    pub passengers: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct CarbonCalcResult {
    pub co2_emitted_kg: f64,
    pub co2_saved_kg: f64,
    pub green_points_earned: i32,
    pub mode: String,
    pub distance_km: f64,
    pub equivalent: String,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct CarbonLog {
    pub id: Uuid,
    pub user_id: Uuid,
    pub mode: String,
    pub distance_km: f64,
    pub co2_kg: f64,
    pub co2_saved_kg: f64,
    pub green_points: i32,
    pub logged_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct FoodCarbonRequest {
    pub food_name: String,
    pub quantity_grams: f64,
    pub origin: Option<String>, // "local" | "imported" | unknown
}

#[derive(Debug, Serialize)]
pub struct FoodCarbonResult {
    pub food_name: String,
    pub co2_kg: f64,
    pub water_liters: f64,
    pub sustainability_score: u8, // 0–100
    pub recommendation: String,
}

// ─── AQI / Civic ─────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct AqiReading {
    pub id: Uuid,
    pub station_id: String,
    pub city: String,
    pub aqi: i32,
    pub pm25: f64,
    pub pm10: f64,
    pub no2: f64,
    pub so2: f64,
    pub co: f64,
    pub o3: f64,
    pub category: String, // "Good"|"Moderate"|"Unhealthy"|"Hazardous"
    pub recorded_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct PollutionReportRequest {
    pub latitude: f64,
    pub longitude: f64,
    pub report_type: String, // "garbage"|"illegal_dump"|"water_contamination"|"deforestation"
    pub description: String,
    pub severity: u8,        // 1–5
    pub photo_url: Option<String>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct PollutionReport {
    pub id: Uuid,
    pub user_id: Uuid,
    pub report_type: String,
    pub description: String,
    pub severity: i16,
    pub latitude: f64,
    pub longitude: f64,
    pub status: String,
    pub photo_url: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct DisasterSosRequest {
    pub latitude: f64,
    pub longitude: f64,
    pub disaster_type: String,
    pub description: String,
    pub needs: Vec<String>,  // ["shelter", "food", "medical", "rescue"]
    pub people_count: u32,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct SosRequest {
    pub id: Uuid,
    pub user_id: Uuid,
    pub disaster_type: String,
    pub description: String,
    pub needs: serde_json::Value,
    pub people_count: i32,
    pub latitude: f64,
    pub longitude: f64,
    pub status: String, // "active"|"matched"|"resolved"
    pub created_at: DateTime<Utc>,
}

// ─── Gamification ────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct GreenPointsBalance {
    pub user_id: Uuid,
    pub total_points: i64,
    pub lifetime_points: i64,
    pub tier: String, // "Seedling"|"Sapling"|"Tree"|"Forest"|"Ecosystem"
    pub rank: i64,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Achievement {
    pub id: Uuid,
    pub user_id: Uuid,
    pub badge_key: String,
    pub badge_name: String,
    pub description: String,
    pub unlocked_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct EcoSquad {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub created_by: Uuid,
    pub member_count: i32,
    pub total_points: i64,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreateSquadRequest {
    pub name: String,
    pub description: Option<String>,
}

// ─── Marketplace / Circular Economy ─────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct MarketplaceListing {
    pub id: Uuid,
    pub seller_id: Uuid,
    pub title: String,
    pub description: String,
    pub listing_type: String,  // "borrow"|"trade"|"donate"|"carbon_credit"
    pub carbon_credits: Option<f64>,
    pub price_points: Option<i32>,
    pub is_available: bool,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreateListingRequest {
    pub title: String,
    pub description: String,
    pub listing_type: String,
    pub carbon_credits: Option<f64>,
    pub price_points: Option<i32>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
}

// ─── Social Feed ─────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct SocialPost {
    pub id: Uuid,
    pub user_id: Uuid,
    pub display_name: String,
    pub action_type: String,
    pub description: String,
    pub co2_saved_kg: Option<f64>,
    pub green_points: Option<i32>,
    pub likes: i32,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreatePostRequest {
    pub action_type: String,
    pub description: String,
    pub co2_saved_kg: Option<f64>,
}

// ─── Pagination ───────────────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct Pagination {
    #[serde(default = "default_page")]
    pub page: u32,
    #[serde(default = "default_limit")]
    pub limit: u32,
}

fn default_page() -> u32 { 1 }
fn default_limit() -> u32 { 20 }

#[derive(Serialize)]
pub struct PaginatedResponse<T: Serialize> {
    pub items: Vec<T>,
    pub page: u32,
    pub limit: u32,
    pub total: i64,
}

// ─── Transport Mode Detection (T10) ─────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct TransportDetectRequest {
    pub speed_kmh: f64,
    pub cadence_spm: Option<f64>,       // steps per minute
    pub altitude_change_m: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct TransportDetection {
    pub detected_mode: String,
    pub confidence: f64,
    pub co2_per_km: f64,
    pub is_green: bool,
    pub suggestion: String,
}

// ─── Lifestyle Auto-Inference (T15) ──────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct LifestyleInferRequest {
    pub step_count: i32,
    pub active_minutes: i32,
    pub cycling_minutes: Option<i32>,
    pub source: Option<String>,         // in_app | strava | fitbit | garmin
}

#[derive(Debug, Serialize)]
pub struct LifestyleInference {
    pub walking_km: f64,
    pub cycling_km: f64,
    pub avoided_co2_kg: f64,
    pub green_points_earned: i32,
    pub activities: Vec<String>,
    pub message: String,
}

// ─── Health-Planet Correlator (T16) ──────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct HealthPlanetCorrelation {
    pub period_days: i64,
    pub avg_daily_co2_kg: f64,
    pub co2_trend: String,             // decreasing | stable | increasing
    pub total_active_minutes: i64,
    pub health_trend: String,
    pub correlation_coefficient: f64,
    pub insight: String,
}

// ─── Supply Chain Tracer (T14) ───────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct SupplyChainRequest {
    pub product_name: String,
    pub barcode: Option<String>,
    pub origin_country: Option<String>,
    pub user_lat: Option<f64>,
    pub user_lon: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct SupplyChainTrace {
    pub product_name: String,
    pub origin_country: String,
    pub origin_coordinates: [f64; 2],
    pub distance_km: f64,
    pub transport_co2_kg: f64,
    pub production_co2_kg: f64,
    pub total_co2_kg: f64,
    pub transport_mode: String,
    pub sustainability_tier: String,
    pub food_miles_label: String,
}

// ─── Weekly Carbon Report (T17) ──────────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct WeeklyCarbonReport {
    pub period_start: String,
    pub period_end: String,
    pub total_co2_kg: f64,
    pub total_saved_kg: f64,
    pub total_points: i64,
    pub trip_count: i64,
    pub best_day: String,
    pub worst_mode: String,
    pub improvement_pct: f64,
    pub summary: String,
}

// ─── EcoLens Product Scanner (T20) ───────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct EcoLensScanRequest {
    pub barcode: String,
    pub product_name: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct EcoLensScanResult {
    pub barcode: String,
    pub product_name: String,
    pub brand: String,
    pub ecoscore_grade: String,        // A | B | C | D | E
    pub sustainability_score: u8,       // 0-100
    pub co2_per_unit_kg: f64,
    pub water_per_unit_l: f64,
    pub packaging_score: u8,
    pub certifications: Vec<String>,
    pub origin_country: String,
    pub is_organic: bool,
    pub recommendation: String,
    pub source: String,
}

// ─── Green Product Recommender (T25) ─────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct AlternativeRequest {
    pub category: String,
    pub original_score: Option<u8>,
}

#[derive(Debug, Serialize, Clone)]
pub struct GreenAlternative {
    pub product_name: String,
    pub brand: String,
    pub category: String,
    pub sustainability_score: u8,
    pub co2_per_unit_kg: f64,
    pub certifications: Vec<String>,
    pub why_better: String,
    pub price_range: String,
}

// ─── Seller Certificate Verification (T27) ──────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct SellerCertRequest {
    pub cert_type: String,             // ISO_14001 | BIS_ECOMARK | FSC | ORGANIC | FAIR_TRADE
    pub cert_number: String,
    pub issuer: String,
    pub expiry_date: String,           // YYYY-MM-DD
    pub document_hash: String,         // SHA-256 hash of uploaded file
}

#[derive(Debug, Serialize)]
pub struct SellerCertResult {
    pub cert_id: String,
    pub status: String,                // verified | rejected | expired
    pub checks_passed: Vec<String>,
    pub checks_failed: Vec<String>,
    pub verified_at: Option<String>,
    pub message: String,
}

// ─── Carbon Offset Suggester (T24) ───────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct OffsetRequest {
    pub target_co2_kg: f64,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct OffsetProject {
    pub id: Uuid,
    pub name: String,
    pub location: String,
    pub project_type: String,
    pub cost_per_kg: f64,
    pub total_capacity_kg: f64,
    pub used_capacity_kg: f64,
    pub certifier: String,
    pub description: String,
}

// ─── Marketplace Impact Calculator (T26) ─────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct MarketplaceImpact {
    pub total_borrows: i64,
    pub total_trades: i64,
    pub total_donations: i64,
    pub avoided_manufacturing_co2_kg: f64,
    pub items_diverted_from_landfill: i64,
    pub green_points_distributed: i64,
    pub equivalent_trees: f64,
    pub period: String,
}

// ─── Circular Economy Stats (T28) ────────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct CircularEconomyStats {
    pub total_listings: i64,
    pub active_listings: i64,
    pub total_transactions: i64,
    pub total_co2_avoided_kg: f64,
    pub total_water_saved_l: f64,
    pub unique_participants: i64,
    pub top_categories: Vec<String>,
    pub circular_velocity: f64,        // transactions per day
}

// ─── AQI Heatmap (T30) ──────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct HeatmapQuery {
    pub city: String,
    pub bbox: Option<Vec<f64>>,        // [min_lat, min_lon, max_lat, max_lon]
}

#[derive(Debug, Serialize)]
pub struct HeatmapPoint {
    pub latitude: f64,
    pub longitude: f64,
    pub aqi: i32,
    pub pm25: f64,
    pub category: String,
    pub station_id: String,
    pub recorded_at: String,
}

#[derive(Debug, Serialize)]
pub struct HeatmapResponse {
    pub city: String,
    pub points: Vec<HeatmapPoint>,
    pub avg_aqi: f64,
    pub total_stations: i64,
    pub weather: WeatherOverlay,
}

#[derive(Debug, Serialize)]
pub struct WeatherOverlay {
    pub temperature_c: f64,
    pub humidity_pct: f64,
    pub wind_speed_kmh: f64,
    pub wind_direction: String,
    pub rainfall_mm: f64,
    pub conditions: String,
}

// ─── Pollution Source Mapper (T32) ───────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct PollutionHotspot {
    pub cluster_id: i64,
    pub center_lat: f64,
    pub center_lon: f64,
    pub report_count: i64,
    pub avg_severity: f64,
    pub dominant_type: String,
    pub radius_m: f64,
    pub label: String,
}

// ─── Municipal Budget Voting (T35) ───────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct VoteRequest {
    pub project_id: String,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct MunicipalProject {
    pub id: Uuid,
    pub ward_id: String,
    pub title: String,
    pub description: String,
    pub budget_points: i32,
    pub votes_count: i32,
    pub status: String,
    pub city: Option<String>,
    pub created_at: DateTime<Utc>,
}

// ─── Health Impact Explainer (T38) ───────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct HealthImpactRequest {
    pub aqi: i32,
    pub user_age: Option<i32>,
    pub has_asthma: Option<bool>,
    pub has_heart_condition: Option<bool>,
    pub is_pregnant: Option<bool>,
    pub exposure_hours: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct HealthImpactResult {
    pub aqi: i32,
    pub risk_level: String,
    pub outdoor_safe_minutes: i32,
    pub mask_recommended: bool,
    pub exercise_safe: bool,
    pub vulnerable_warnings: Vec<String>,
    pub recommendations: Vec<String>,
    pub long_term_risk: String,
}

// ─── Challenge Generator (T45) ───────────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct DailyChallenge {
    pub id: Uuid,
    pub user_id: Uuid,
    pub title: String,
    pub description: String,
    pub category: String,
    pub reward_points: i32,
    pub difficulty: String,
    pub expires_at: DateTime<Utc>,
    pub completed: bool,
    pub created_at: DateTime<Utc>,
}

// ─── Behavior Analyzer (T55) ────────────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct BehaviorAnalysis {
    pub user_id: String,
    pub dominant_transport: String,
    pub avg_daily_co2_kg: f64,
    pub weekly_pattern: Vec<DayPattern>,
    pub habits: Vec<String>,
    pub ai_insight: String,
}

#[derive(Debug, Serialize)]
pub struct DayPattern {
    pub day: String,
    pub avg_co2_kg: f64,
    pub trip_count: i64,
    pub dominant_mode: String,
}

// ─── Anomaly Explainer (T56) ─────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct AnomalyRequest {
    pub metric: Option<String>,        // co2 | points | reports
    pub days: Option<i64>,
}

#[derive(Debug, Serialize)]
pub struct AnomalyExplanation {
    pub anomaly_detected: bool,
    pub metric: String,
    pub normal_avg: f64,
    pub current_value: f64,
    pub deviation_pct: f64,
    pub explanation: String,
    pub likely_cause: String,
    pub recommendation: String,
}

// ─── Nudge Scheduler (T52) ──────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct NudgeScheduleRequest {
    pub nudge_type: String,
    pub message: String,
    pub fire_at_hour: i32,
    pub fire_at_minute: Option<i32>,
    pub days_of_week: Option<String>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct NudgeSchedule {
    pub id: Uuid,
    pub user_id: Uuid,
    pub nudge_type: String,
    pub message: String,
    pub fire_at_hour: i32,
    pub fire_at_minute: i32,
    pub days_of_week: String,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
}

// ─── Notification Sender (T51) ──────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct NotificationRequest {
    pub target_user_id: String,
    pub title: String,
    pub body: String,
    pub data: Option<serde_json::Value>,
}

#[derive(Debug, Serialize)]
pub struct NotificationResult {
    pub sent: bool,
    pub method: String,
    pub target_user_id: String,
    pub message: String,
}

// ─── Admin Override (T58) ────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct AdminOverrideRequest {
    pub action: String,     // enter_survival | exit_survival | reset_leaderboard | ban_user | unban_user | seed_data
    pub target_id: Option<String>,
    pub reason: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct AdminOverrideResult {
    pub action: String,
    pub success: bool,
    pub affected: i64,
    pub details: String,
    pub audit_id: String,
}
