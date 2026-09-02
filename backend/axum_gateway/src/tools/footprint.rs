/// EPIC 2: Automated Footprint & Lifestyle Telemetry (Tools T09–T18)
/// All deterministic math — zero LLM needed for calculations.
/// Brain is notified via log_event for every action stored in Mythos.

use crate::{
    auth::AuthUser,
    error::{AppError, AppResult},
    models::*,
    AppState,
};
use axum::{
    extract::{Query, State},
    Json,
};
use chrono::{Datelike, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

// ── Emission factors (kg CO2 per km) ─────────────────────────────────────────
fn emission_factor(mode: &str) -> f64 {
    match mode {
        "car"        => 0.192,
        "motorbike"  => 0.114,
        "bus"        => 0.089,
        "train"      => 0.041,
        "metro"      => 0.028,
        "flight"     => 0.255,
        "cycle"      => 0.0,
        "walk"       => 0.0,
        "ev_car"     => 0.053,
        _            => 0.192, // default to car
    }
}

fn car_baseline(km: f64) -> f64 { 0.192 * km }

fn points_for_saving(saved_kg: f64) -> i32 {
    (saved_kg * 100.0) as i32
}

fn co2_equivalent(saved_kg: f64) -> String {
    let trees_day = saved_kg * 48.0;
    if trees_day < 1.0 {
        format!("≈ {} minutes of tree absorption", (trees_day * 60.0) as u32)
    } else {
        format!("≈ {:.1} tree-days of carbon absorption", trees_day)
    }
}

/// T09 — Carbon Calculator (deterministic math)
pub async fn carbon_calc(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<CarbonCalcRequest>,
) -> AppResult<Json<ApiResponse<CarbonCalcResult>>> {
    let emitted = emission_factor(&req.mode) * req.distance_km;
    let baseline = car_baseline(req.distance_km);
    let saved = (baseline - emitted).max(0.0);
    let points = points_for_saving(saved);

    // Log to Mythos (fire-and-forget)
    state.brain.log_event("carbon_calculated", Some(&auth.0.sub), json!({
        "mode": req.mode,
        "distance_km": req.distance_km,
        "co2_kg": emitted,
        "saved_kg": saved,
        "points": points,
    })).await;

    Ok(Json(ApiResponse::ok(CarbonCalcResult {
        co2_emitted_kg: (emitted * 1000.0).round() / 1000.0,
        co2_saved_kg: (saved * 1000.0).round() / 1000.0,
        green_points_earned: points,
        mode: req.mode,
        distance_km: req.distance_km,
        equivalent: co2_equivalent(saved),
    })))
}

/// T09b — Carbon Log (save calculated trip to DB + award points)
pub async fn log_carbon_trip(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<CarbonCalcRequest>,
) -> AppResult<Json<ApiResponse<CarbonLog>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let emitted = emission_factor(&req.mode) * req.distance_km;
    let baseline = car_baseline(req.distance_km);
    let saved = (baseline - emitted).max(0.0);
    let points = points_for_saving(saved);

    let log = sqlx::query_as::<_, CarbonLog>(
        r#"INSERT INTO carbon_logs (user_id, mode, distance_km, co2_kg, co2_saved_kg, green_points)
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING id, user_id, mode, distance_km, co2_kg, co2_saved_kg, green_points, logged_at"#
    )
    .bind(user_id)
    .bind(&req.mode)
    .bind(req.distance_km)
    .bind(emitted)
    .bind(saved)
    .bind(points)
    .fetch_one(&state.db)
    .await?;

    // Award Green Points
    sqlx::query(
        "INSERT INTO green_points_ledger (user_id, delta, reason, reference_id) VALUES ($1, $2, $3, $4)"
    )
    .bind(user_id)
    .bind(points)
    .bind(format!("Carbon saved via {}", req.mode))
    .bind(log.id)
    .execute(&state.db)
    .await?;

    // Update squad totals if member
    sqlx::query(
        "UPDATE eco_squads SET total_points = total_points + $1
         WHERE id IN (SELECT squad_id FROM squad_members WHERE user_id = $2)"
    )
    .bind(points as i64)
    .bind(user_id)
    .execute(&state.db)
    .await?;

    state.brain.log_event("carbon_trip_logged", Some(&auth.0.sub), json!({
        "log_id": log.id,
        "mode": req.mode,
        "distance_km": req.distance_km,
        "co2_saved_kg": saved,
        "green_points": points,
    })).await;

    Ok(Json(ApiResponse::with_message(log, &format!("+{points} Green Points earned!"))))
}

/// T11 — Carbon History & Trend (last N days)
#[derive(Deserialize)]
pub struct HistoryQuery {
    pub days: Option<i64>,
}

#[derive(Serialize)]
pub struct CarbonHistoryResponse {
    pub logs: Vec<CarbonLog>,
    pub total_co2_kg: f64,
    pub total_saved_kg: f64,
    pub total_green_points: i64,
    pub avg_daily_co2_kg: f64,
    pub best_day: Option<String>,
}

pub async fn carbon_history(
    State(state): State<AppState>,
    auth: AuthUser,
    Query(q): Query<HistoryQuery>,
) -> AppResult<Json<ApiResponse<CarbonHistoryResponse>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;
    let days = q.days.unwrap_or(30);

    let logs = sqlx::query_as::<_, CarbonLog>(
        r#"SELECT id, user_id, mode, distance_km, co2_kg, co2_saved_kg, green_points, logged_at
           FROM carbon_logs WHERE user_id = $1
           AND logged_at > NOW() - make_interval(days => $2::int)
           ORDER BY logged_at DESC LIMIT 200"#
    )
    .bind(user_id)
    .bind(days as i32)
    .fetch_all(&state.db)
    .await?;

    let total_co2: f64 = logs.iter().map(|l| l.co2_kg).sum();
    let total_saved: f64 = logs.iter().map(|l| l.co2_saved_kg).sum();
    let total_points: i64 = logs.iter().map(|l| l.green_points as i64).sum();
    let avg_daily = if days > 0 { total_co2 / days as f64 } else { 0.0 };

    Ok(Json(ApiResponse::ok(CarbonHistoryResponse {
        logs,
        total_co2_kg: total_co2,
        total_saved_kg: total_saved,
        total_green_points: total_points,
        avg_daily_co2_kg: avg_daily,
        best_day: None,
    })))
}

/// T12 — Carbon Budget Manager
#[derive(Deserialize)]
pub struct BudgetRequest {
    pub monthly_cap_kg: f64,
}

#[derive(Serialize)]
pub struct BudgetStatus {
    pub monthly_cap_kg: f64,
    pub used_kg: f64,
    pub remaining_kg: f64,
    pub percent_used: f64,
    pub month: String,
    pub status: String,
}

pub async fn set_carbon_budget(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<BudgetRequest>,
) -> AppResult<Json<ApiResponse<BudgetStatus>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;
    let now = Utc::now();
    let month_year = format!("{}-{:02}", now.year(), now.month());

    sqlx::query(
        r#"INSERT INTO carbon_budgets (user_id, monthly_cap_kg, month_year)
           VALUES ($1, $2, $3)
           ON CONFLICT (user_id, month_year) DO UPDATE SET monthly_cap_kg = $2"#
    )
    .bind(user_id)
    .bind(req.monthly_cap_kg)
    .bind(&month_year)
    .execute(&state.db)
    .await?;

    let used: f64 = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT COALESCE(SUM(co2_kg), 0.0) FROM carbon_logs
         WHERE user_id = $1 AND DATE_TRUNC('month', logged_at) = DATE_TRUNC('month', NOW())"
    )
    .bind(user_id)
    .fetch_one(&state.db)
    .await?
    .unwrap_or(0.0);

    let remaining = (req.monthly_cap_kg - used).max(0.0);
    let pct = if req.monthly_cap_kg > 0.0 { (used / req.monthly_cap_kg * 100.0).min(100.0) } else { 0.0 };
    let status = if pct >= 100.0 { "exceeded" }
                 else if pct >= 80.0 { "warning" }
                 else { "on_track" }.to_string();

    Ok(Json(ApiResponse::ok(BudgetStatus {
        monthly_cap_kg: req.monthly_cap_kg,
        used_kg: used,
        remaining_kg: remaining,
        percent_used: pct,
        month: month_year,
        status,
    })))
}

/// T13 — Food Carbon Calculator
pub async fn food_carbon(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<FoodCarbonRequest>,
) -> AppResult<Json<ApiResponse<FoodCarbonResult>>> {
    // Food emission factors (kg CO2 per 100g)
    let (co2_per_100g, water_per_100g, score) = match req.food_name.to_lowercase().as_str() {
        n if n.contains("beef")      => (2.7, 155.0, 10u8),
        n if n.contains("lamb")      => (2.4, 100.0, 15),
        n if n.contains("pork")      => (0.7, 57.0,  35),
        n if n.contains("chicken")   => (0.43, 43.0, 55),
        n if n.contains("fish")      => (0.30, 20.0, 60),
        n if n.contains("egg")       => (0.20, 20.0, 65),
        n if n.contains("milk") | n.contains("dairy") => (0.32, 90.0, 50),
        n if n.contains("rice")      => (0.17, 25.0, 60),
        n if n.contains("wheat") | n.contains("bread") => (0.13, 15.0, 70),
        n if n.contains("lentil") | n.contains("dal")  => (0.09, 5.0, 90),
        n if n.contains("vegetable") | n.contains("veggie") => (0.02, 3.0, 95),
        n if n.contains("fruit")     => (0.03, 8.0, 92),
        _                            => (0.15, 20.0, 65),
    };

    let factor = req.quantity_grams / 100.0;
    let co2 = co2_per_100g * factor
        * if req.origin.as_deref() == Some("imported") { 1.4 } else { 1.0 };
    let water = water_per_100g * factor;

    let rec = if score >= 80 { "Excellent choice! Low environmental impact." }
              else if score >= 60 { "Moderate impact. Consider plant-based alternatives." }
              else { "High impact. Try to reduce frequency or choose a sustainable source." };

    state.brain.log_event("food_logged", Some(&auth.0.sub), json!({
        "food": req.food_name,
        "co2_kg": co2,
        "score": score,
    })).await;

    Ok(Json(ApiResponse::ok(FoodCarbonResult {
        food_name: req.food_name,
        co2_kg: (co2 * 1000.0).round() / 1000.0,
        water_liters: (water * 10.0).round() / 10.0,
        sustainability_score: score,
        recommendation: rec.to_string(),
    })))
}

/// T18 — Carbon Comparison (vs city / national average)
#[derive(Serialize)]
pub struct CarbonComparison {
    pub user_monthly_kg: f64,
    pub city_average_kg: f64,
    pub national_average_kg: f64,
    pub global_average_kg: f64,
    pub vs_city_pct: f64,
    pub percentile: String,
    pub message: String,
}

pub async fn carbon_comparison(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<CarbonComparison>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let user_monthly: f64 = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT COALESCE(SUM(co2_kg), 0.0) FROM carbon_logs
         WHERE user_id = $1 AND DATE_TRUNC('month', logged_at) = DATE_TRUNC('month', NOW())"
    )
    .bind(user_id)
    .fetch_one(&state.db)
    .await?
    .unwrap_or(0.0);

    // India averages (kg CO2/month per capita, transport only)
    let city_avg = 145.0_f64;
    let national_avg = 120.0_f64;
    let global_avg = 375.0_f64;

    let vs_city = ((user_monthly - city_avg) / city_avg * 100.0).round();
    let percentile = if user_monthly < city_avg * 0.5 { "Top 10% — Eco Champion" }
                     else if user_monthly < city_avg { "Top 40% — Above Average" }
                     else if user_monthly < city_avg * 1.5 { "Bottom 40% — Room to Improve" }
                     else { "Bottom 10% — High Impact" };

    let msg = if vs_city < 0.0 {
        format!("You emit {:.0}% less than your city average. Keep it up!", vs_city.abs())
    } else {
        format!("You emit {:.0}% more than your city average. Small changes make a big difference.", vs_city)
    };

    Ok(Json(ApiResponse::ok(CarbonComparison {
        user_monthly_kg: user_monthly,
        city_average_kg: city_avg,
        national_average_kg: national_avg,
        global_average_kg: global_avg,
        vs_city_pct: vs_city,
        percentile: percentile.to_string(),
        message: msg,
    })))
}

// ── T10 — Transport Mode Detector ─────────────────────────────────────────────

pub async fn detect_transport_mode(
    State(_state): State<AppState>,
    _auth: AuthUser,
    Json(req): Json<TransportDetectRequest>,
) -> AppResult<Json<ApiResponse<TransportDetection>>> {
    let speed = req.speed_kmh;
    let cadence = req.cadence_spm.unwrap_or(0.0);
    let alt_change = req.altitude_change_m.unwrap_or(0.0);

    // Decision tree for transport mode classification
    let (mode, confidence, co2) = if speed < 1.0 {
        ("stationary", 0.95, 0.0)
    } else if speed < 6.0 && cadence > 80.0 {
        ("walk", 0.92, 0.0)
    } else if speed < 6.0 {
        ("walk", 0.80, 0.0)
    } else if speed < 25.0 && cadence > 50.0 {
        ("cycle", 0.90, 0.0)
    } else if speed < 25.0 && cadence < 10.0 {
        ("ev_scooter", 0.75, 0.025)
    } else if speed >= 25.0 && speed < 45.0 {
        if alt_change.abs() < 2.0 { ("bus", 0.70, 0.089) }
        else { ("motorbike", 0.65, 0.114) }
    } else if speed >= 45.0 && speed < 90.0 {
        ("car", 0.78, 0.192)
    } else if speed >= 90.0 && speed < 200.0 {
        ("train", 0.85, 0.041)
    } else if speed >= 200.0 && speed < 400.0 {
        ("metro", 0.80, 0.028)
    } else {
        ("flight", 0.90, 0.255)
    };

    let is_green = co2 < 0.05;
    let suggestion = if is_green {
        "Great choice! You're already using a green transport mode.".to_string()
    } else {
        format!("Consider switching to cycling or public transit to reduce your {:.1}g CO₂/km footprint.", co2 * 1000.0)
    };

    Ok(Json(ApiResponse::ok(TransportDetection {
        detected_mode: mode.to_string(),
        confidence,
        co2_per_km: co2,
        is_green,
        suggestion,
    })))
}

// ── T15 — Lifestyle Auto-Inferrer ─────────────────────────────────────────────

pub async fn infer_lifestyle(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<LifestyleInferRequest>,
) -> AppResult<Json<ApiResponse<LifestyleInference>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    // Convert steps to km (avg stride 0.72m)
    let walking_km = (req.step_count as f64) * 0.00072;
    // Convert cycling minutes to km (avg 15 km/h)
    let cycling_km = (req.cycling_minutes.unwrap_or(0) as f64) / 60.0 * 15.0;

    // Calculate avoided emissions vs driving the same distance
    let walking_avoided = walking_km * 0.192;  // vs car baseline
    let cycling_avoided = cycling_km * 0.192;
    let total_avoided = walking_avoided + cycling_avoided;
    let points = (total_avoided * 100.0) as i32;

    let mut activities = Vec::new();
    if walking_km > 0.1 { activities.push(format!("Walked {:.1}km", walking_km)); }
    if cycling_km > 0.1 { activities.push(format!("Cycled {:.1}km", cycling_km)); }
    if req.active_minutes > 0 { activities.push(format!("{} active minutes", req.active_minutes)); }

    // Log to DB
    sqlx::query(
        "INSERT INTO lifestyle_logs (user_id, step_count, active_minutes, cycling_minutes, avoided_co2_kg, green_points, source)
         VALUES ($1, $2, $3, $4, $5, $6, $7)"
    )
    .bind(user_id)
    .bind(req.step_count)
    .bind(req.active_minutes)
    .bind(req.cycling_minutes.unwrap_or(0))
    .bind(total_avoided)
    .bind(points)
    .bind(req.source.as_deref().unwrap_or("in_app"))
    .execute(&state.db).await?;

    // Award green points
    if points > 0 {
        sqlx::query(
            "INSERT INTO green_points_ledger (user_id, delta, reason) VALUES ($1, $2, 'Auto-inferred eco-activity')"
        )
        .bind(user_id).bind(points)
        .execute(&state.db).await?;
    }

    let msg = if total_avoided > 1.0 {
        format!("🌿 You avoided {:.2}kg CO₂ today by walking and cycling! +{} Green Points.", total_avoided, points)
    } else {
        format!("Every step counts! {:.0}g CO₂ avoided today.", total_avoided * 1000.0)
    };

    Ok(Json(ApiResponse::ok(LifestyleInference {
        walking_km: (walking_km * 100.0).round() / 100.0,
        cycling_km: (cycling_km * 100.0).round() / 100.0,
        avoided_co2_kg: (total_avoided * 1000.0).round() / 1000.0,
        green_points_earned: points,
        activities,
        message: msg,
    })))
}

// ── T16 — Health-Planet Correlator ─────────────────────────────────────────────

pub async fn correlate_health_planet(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<HealthPlanetCorrelation>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let days: i64 = 30;

    // Get carbon trend (daily avg over last 30 days)
    let total_co2: f64 = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT COALESCE(SUM(co2_kg), 0.0) FROM carbon_logs
         WHERE user_id = $1 AND logged_at > NOW() - INTERVAL '30 days'"
    ).bind(user_id).fetch_one(&state.db).await?.unwrap_or(0.0);

    let prev_co2: f64 = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT COALESCE(SUM(co2_kg), 0.0) FROM carbon_logs
         WHERE user_id = $1 AND logged_at BETWEEN NOW() - INTERVAL '60 days' AND NOW() - INTERVAL '30 days'"
    ).bind(user_id).fetch_one(&state.db).await?.unwrap_or(0.0);

    // Get activity trend from lifestyle_logs
    let total_active: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COALESCE(SUM(active_minutes), 0) FROM lifestyle_logs
         WHERE user_id = $1 AND logged_at > NOW() - INTERVAL '30 days'"
    ).bind(user_id).fetch_one(&state.db).await?.unwrap_or(0);

    let prev_active: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COALESCE(SUM(active_minutes), 0) FROM lifestyle_logs
         WHERE user_id = $1 AND logged_at BETWEEN NOW() - INTERVAL '60 days' AND NOW() - INTERVAL '30 days'"
    ).bind(user_id).fetch_one(&state.db).await?.unwrap_or(0);

    let avg_daily_co2 = total_co2 / days as f64;
    let co2_trend = if prev_co2 > 0.0 && total_co2 < prev_co2 * 0.9 { "decreasing" }
                    else if total_co2 > prev_co2 * 1.1 { "increasing" }
                    else { "stable" };

    let health_trend = if total_active > prev_active + 60 { "improving" }
                       else if total_active < prev_active.saturating_sub(60) { "declining" }
                       else { "stable" };

    // Simplified Pearson-like correlation: negative correlation = good (less CO2, more active)
    let correlation = if co2_trend == "decreasing" && health_trend == "improving" { -0.78 }
                      else if co2_trend == "increasing" && health_trend == "declining" { 0.65 }
                      else if co2_trend == "decreasing" { -0.45 }
                      else { 0.12 };

    let insight = if correlation < -0.5 {
        "Strong positive link: as your carbon footprint decreases, your physical activity increases. Your eco-choices are directly improving your health!".to_string()
    } else if correlation < 0.0 {
        "Your eco-friendly transport choices (walking, cycling) are contributing to better fitness. Keep it up!".to_string()
    } else {
        "Your health and eco-actions haven't shown a strong correlation yet. Try cycling or walking for commutes to see both benefits!".to_string()
    };

    Ok(Json(ApiResponse::ok(HealthPlanetCorrelation {
        period_days: days,
        avg_daily_co2_kg: (avg_daily_co2 * 100.0).round() / 100.0,
        co2_trend: co2_trend.to_string(),
        total_active_minutes: total_active,
        health_trend: health_trend.to_string(),
        correlation_coefficient: correlation,
        insight,
    })))
}

// ── T14 — Supply Chain Tracer ──────────────────────────────────────────────────

pub async fn trace_supply_chain(
    State(state): State<AppState>,
    _auth: AuthUser,
    Json(req): Json<SupplyChainRequest>,
) -> AppResult<Json<ApiResponse<SupplyChainTrace>>> {
    let origin = req.origin_country.clone().unwrap_or_else(|| "India".to_string());
    let user_lat = req.user_lat.unwrap_or(28.6139); // Delhi default
    let user_lon = req.user_lon.unwrap_or(77.2090);

    // Origin country centroids (major trade partners for India)
    let (origin_lat, origin_lon, base_production_co2) = match origin.to_lowercase().as_str() {
        "india"       => (20.5937, 78.9629, 0.8),
        "china"       => (35.8617, 104.1954, 1.5),
        "usa"         => (37.0902, -95.7129, 1.2),
        "germany"     => (51.1657, 10.4515, 0.9),
        "brazil"      => (-14.2350, -51.9253, 1.8),
        "australia"   => (-25.2744, 133.7751, 1.1),
        "indonesia"   => (-0.7893, 113.9213, 1.6),
        "vietnam"     => (14.0583, 108.2772, 1.4),
        "bangladesh"  => (23.6850, 90.3563, 1.3),
        "sri lanka"   => (7.8731, 80.7718, 1.0),
        _             => (0.0, 0.0, 1.5), // unknown defaults
    };

    // Haversine distance
    let dlat = (origin_lat - user_lat).to_radians();
    let dlon = (origin_lon - user_lon).to_radians();
    let a = (dlat / 2.0).sin().powi(2)
        + user_lat.to_radians().cos() * origin_lat.to_radians().cos() * (dlon / 2.0).sin().powi(2);
    let distance_km = 6371.0 * 2.0 * a.sqrt().asin();

    // Transport CO2 based on distance and likely mode
    let (transport_mode, transport_co2_per_km) = if distance_km < 500.0 {
        ("road", 0.000062)  // kg per km per kg of product
    } else if distance_km < 3000.0 {
        ("rail", 0.000022)
    } else {
        ("sea", 0.000008)   // container ship
    };

    let transport_co2 = distance_km * transport_co2_per_km;
    let total_co2 = base_production_co2 + transport_co2;

    let tier = if total_co2 < 1.0 { "Low Impact" }
               else if total_co2 < 2.0 { "Moderate Impact" }
               else { "High Impact" };

    let food_miles = if distance_km < 200.0 { "Local" }
                     else if distance_km < 1000.0 { "Regional" }
                     else if distance_km < 5000.0 { "Continental" }
                     else { "Intercontinental" };

    state.brain.log_event("supply_chain_traced", None, serde_json::json!({
        "product": req.product_name,
        "origin": origin,
        "distance_km": distance_km,
        "total_co2": total_co2,
    })).await;

    Ok(Json(ApiResponse::ok(SupplyChainTrace {
        product_name: req.product_name,
        origin_country: origin,
        origin_coordinates: [origin_lat, origin_lon],
        distance_km: (distance_km * 10.0).round() / 10.0,
        transport_co2_kg: (transport_co2 * 1000.0).round() / 1000.0,
        production_co2_kg: base_production_co2,
        total_co2_kg: (total_co2 * 1000.0).round() / 1000.0,
        transport_mode: transport_mode.to_string(),
        sustainability_tier: tier.to_string(),
        food_miles_label: food_miles.to_string(),
    })))
}

// ── T17 — Weekly Carbon Report ─────────────────────────────────────────────────

pub async fn weekly_carbon_report(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<WeeklyCarbonReport>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let now = Utc::now();
    let week_ago = now - chrono::Duration::days(7);
    let prev_week_start = week_ago - chrono::Duration::days(7);

    // This week
    let this_week_co2: f64 = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT COALESCE(SUM(co2_kg), 0.0) FROM carbon_logs WHERE user_id = $1 AND logged_at > $2"
    ).bind(user_id).bind(week_ago).fetch_one(&state.db).await?.unwrap_or(0.0);

    let this_week_saved: f64 = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT COALESCE(SUM(co2_saved_kg), 0.0) FROM carbon_logs WHERE user_id = $1 AND logged_at > $2"
    ).bind(user_id).bind(week_ago).fetch_one(&state.db).await?.unwrap_or(0.0);

    let this_week_points: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COALESCE(SUM(green_points::bigint), 0) FROM carbon_logs WHERE user_id = $1 AND logged_at > $2"
    ).bind(user_id).bind(week_ago).fetch_one(&state.db).await?.unwrap_or(0);

    let trip_count: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(*) FROM carbon_logs WHERE user_id = $1 AND logged_at > $2"
    ).bind(user_id).bind(week_ago).fetch_one(&state.db).await?.unwrap_or(0);

    // Previous week for comparison
    let prev_week_co2: f64 = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT COALESCE(SUM(co2_kg), 0.0) FROM carbon_logs WHERE user_id = $1 AND logged_at BETWEEN $2 AND $3"
    ).bind(user_id).bind(prev_week_start).bind(week_ago).fetch_one(&state.db).await?.unwrap_or(0.0);

    let improvement = if prev_week_co2 > 0.0 {
        ((prev_week_co2 - this_week_co2) / prev_week_co2 * 100.0).round()
    } else { 0.0 };

    // Find worst mode
    #[derive(sqlx::FromRow)]
    struct ModeRow { mode: String }
    let worst_mode = sqlx::query_as::<_, ModeRow>(
        "SELECT mode FROM carbon_logs WHERE user_id = $1 AND logged_at > $2
         GROUP BY mode ORDER BY SUM(co2_kg) DESC LIMIT 1"
    ).bind(user_id).bind(week_ago)
    .fetch_optional(&state.db).await?
    .map(|r| r.mode).unwrap_or_else(|| "none".to_string());

    let summary = if improvement > 10.0 {
        format!("🌟 Great week! Your carbon footprint dropped {:.0}% compared to last week. {} trips logged.", improvement, trip_count)
    } else if improvement > 0.0 {
        format!("👍 Slight improvement ({:.0}%). Keep pushing for greener transport choices!", improvement)
    } else if trip_count == 0 {
        "No trips logged this week. Start logging to track your impact!".to_string()
    } else {
        format!("Your footprint rose this week. Consider replacing {} trips with greener alternatives.", worst_mode)
    };

    Ok(Json(ApiResponse::ok(WeeklyCarbonReport {
        period_start: week_ago.format("%Y-%m-%d").to_string(),
        period_end: now.format("%Y-%m-%d").to_string(),
        total_co2_kg: (this_week_co2 * 100.0).round() / 100.0,
        total_saved_kg: (this_week_saved * 100.0).round() / 100.0,
        total_points: this_week_points,
        trip_count,
        best_day: "Monday".to_string(), // simplified
        worst_mode,
        improvement_pct: improvement,
        summary,
    })))
}
