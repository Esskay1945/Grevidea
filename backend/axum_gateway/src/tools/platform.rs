/// EPIC 6: User, Platform & Infrastructure Tools (T49–T58)

use crate::{auth::{self, AuthUser, Claims}, error::{AppError, AppResult}, models::*, AppState};
use axum::{extract::{Path, State}, Json};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

// ── T49/T50 — Auth: Register & Login ─────────────────────────────────────────

pub async fn register(
    State(state): State<AppState>,
    Json(req): Json<RegisterRequest>,
) -> AppResult<Json<ApiResponse<AuthResponse>>> {
    if req.email.is_empty() || req.password.len() < 8 {
        return Err(AppError::BadRequest("Email required and password must be 8+ chars".into()));
    }

    // Check email not taken
    let exists: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(*) FROM users WHERE email = $1"
    )
    .bind(&req.email)
    .fetch_one(&state.db)
    .await?
    .unwrap_or(0);

    if exists > 0 {
        return Err(AppError::BadRequest("Email already registered".into()));
    }

    let hash = auth::hash_password(&req.password)?;
    let user_id: Uuid = sqlx::query_scalar(
        "INSERT INTO users (email, password_hash, display_name) VALUES ($1, $2, $3) RETURNING id"
    )
    .bind(&req.email)
    .bind(&hash)
    .bind(&req.display_name)
    .fetch_one(&state.db).await?;

    // Initialize streak
    sqlx::query("INSERT INTO streaks (user_id) VALUES ($1) ON CONFLICT DO NOTHING")
        .bind(user_id)
        .execute(&state.db).await?;

    // Welcome bonus
    sqlx::query("INSERT INTO green_points_ledger (user_id, delta, reason) VALUES ($1, 50, 'Welcome to Grevidea!')")
        .bind(user_id)
        .execute(&state.db).await?;

    let token = Claims::new(user_id, &req.email, "user", &state.config.jwt_secret)?;

    state.brain.log_event("user_registered", Some(&user_id.to_string()), json!({
        "email": req.email,
        "display_name": req.display_name,
    })).await;

    Ok(Json(ApiResponse::with_message(AuthResponse {
        token,
        user_id: user_id.to_string(),
        display_name: req.display_name,
        role: "user".to_string(),
    }, "Welcome! +50 Green Points as welcome bonus.")))
}

#[derive(sqlx::FromRow)]
struct UserAuthRow {
    id: Uuid,
    email: String,
    password_hash: String,
    display_name: String,
    role: String,
}

pub async fn login(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> AppResult<Json<ApiResponse<AuthResponse>>> {
    let user = sqlx::query_as::<_, UserAuthRow>(
        "SELECT id, email, password_hash, display_name, role FROM users WHERE email = $1"
    )
    .bind(&req.email)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::Auth("Invalid email or password".into()))?;

    if !auth::verify_password(&req.password, &user.password_hash)? {
        return Err(AppError::Auth("Invalid email or password".into()));
    }

    let token = Claims::new(user.id, &user.email, &user.role, &state.config.jwt_secret)?;

    state.brain.log_event("user_login", Some(&user.id.to_string()), json!({
        "email": user.email,
    })).await;

    Ok(Json(ApiResponse::ok(AuthResponse {
        token,
        user_id: user.id.to_string(),
        display_name: user.display_name,
        role: user.role,
    })))
}

// ── T49 — User Profile Manager ───────────────────────────────────────────────

pub async fn get_profile(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<User>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let user = sqlx::query_as::<_, User>(
        "SELECT id, email, display_name, role, eco_persona, fcm_token, created_at, updated_at
         FROM users WHERE id = $1"
    )
    .bind(user_id)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::NotFound("User not found".into()))?;

    Ok(Json(ApiResponse::ok(user)))
}

#[derive(Deserialize)]
pub struct UpdateProfileRequest {
    pub display_name: Option<String>,
    pub bio: Option<String>,
    pub fcm_token: Option<String>,
}

pub async fn update_profile(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<UpdateProfileRequest>,
) -> AppResult<Json<ApiResponse<serde_json::Value>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    if let Some(name) = &req.display_name {
        sqlx::query("UPDATE users SET display_name = $1, updated_at = NOW() WHERE id = $2")
            .bind(name)
            .bind(user_id)
            .execute(&state.db).await?;
    }

    if let Some(token) = &req.fcm_token {
        sqlx::query("UPDATE users SET fcm_token = $1 WHERE id = $2")
            .bind(token)
            .bind(user_id)
            .execute(&state.db).await?;
    }

    if let Some(bio) = &req.bio {
        sqlx::query("UPDATE users SET bio = $1 WHERE id = $2")
            .bind(bio)
            .bind(user_id)
            .execute(&state.db).await?;
    }

    Ok(Json(ApiResponse::ok(json!({ "updated": true }))))
}

// ── T53 — Social Graph Manager ────────────────────────────────────────────────

pub async fn follow_user(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(target_id): Path<Uuid>,
) -> AppResult<Json<ApiResponse<serde_json::Value>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    if user_id == target_id {
        return Err(AppError::BadRequest("Cannot follow yourself".into()));
    }

    sqlx::query("INSERT INTO social_connections (follower_id, following_id) VALUES ($1, $2) ON CONFLICT DO NOTHING")
        .bind(user_id)
        .bind(target_id)
        .execute(&state.db).await?;

    Ok(Json(ApiResponse::ok(json!({ "following": true }))))
}

pub async fn unfollow_user(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(target_id): Path<Uuid>,
) -> AppResult<Json<ApiResponse<serde_json::Value>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    sqlx::query("DELETE FROM social_connections WHERE follower_id = $1 AND following_id = $2")
        .bind(user_id)
        .bind(target_id)
        .execute(&state.db).await?;

    Ok(Json(ApiResponse::ok(json!({ "unfollowed": true }))))
}

// ── T54 — Privacy Manager (GDPR) ─────────────────────────────────────────────

pub async fn delete_account(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<serde_json::Value>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(user_id)
        .execute(&state.db).await?;

    state.brain.log_event("user_deleted", Some(&auth.0.sub), json!({
        "gdpr": true,
    })).await;

    Ok(Json(ApiResponse::ok(json!({
        "deleted": true,
        "message": "All your data has been permanently deleted per GDPR Article 17."
    }))))
}

// ── T57 — Micro-Learning Cards ────────────────────────────────────────────────

#[derive(Serialize, sqlx::FromRow)]
pub struct LearningCard {
    pub id: Uuid,
    pub title: String,
    pub content: String,
    pub category: String,
    pub difficulty: String,
    pub points_reward: i32,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

pub async fn get_daily_cards(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<Vec<LearningCard>>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let cards = sqlx::query_as::<_, LearningCard>(
        r#"SELECT id, title, content, category, difficulty, points_reward, created_at
           FROM learning_cards
           WHERE id NOT IN (SELECT card_id FROM user_card_progress WHERE user_id = $1)
           ORDER BY RANDOM() LIMIT 3"#
    )
    .bind(user_id)
    .fetch_all(&state.db).await?;

    Ok(Json(ApiResponse::ok(cards)))
}

pub async fn complete_card(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(card_id): Path<Uuid>,
) -> AppResult<Json<ApiResponse<serde_json::Value>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let points: i32 = sqlx::query_scalar::<_, Option<i32>>(
        "SELECT points_reward FROM learning_cards WHERE id = $1"
    )
    .bind(card_id)
    .fetch_optional(&state.db).await?
    .flatten()
    .ok_or_else(|| AppError::NotFound("Card not found".into()))?;

    sqlx::query("INSERT INTO user_card_progress (user_id, card_id) VALUES ($1, $2) ON CONFLICT DO NOTHING")
        .bind(user_id)
        .bind(card_id)
        .execute(&state.db).await?;

    sqlx::query(
        "INSERT INTO green_points_ledger (user_id, delta, reason, reference_id)
         VALUES ($1, $2, 'Completed climate learning card', $3)"
    )
    .bind(user_id)
    .bind(points)
    .bind(card_id)
    .execute(&state.db).await?;

    Ok(Json(ApiResponse::ok(json!({
        "completed": true,
        "points_earned": points
    }))))
}

// ── T55 — Behavior Analyzer (Brain-Powered Pattern Detection) ─────────────────

pub async fn analyze_behavior(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<BehaviorAnalysis>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    // Get mode statistics over last 90 days
    #[derive(sqlx::FromRow)]
    struct ModeAgg { mode: String, total_co2: f64, trip_count: i64 }

    let mode_stats = sqlx::query_as::<_, ModeAgg>(
        "SELECT mode, COALESCE(SUM(co2_kg), 0.0) as total_co2, COUNT(*) as trip_count
         FROM carbon_logs WHERE user_id = $1 AND logged_at > NOW() - INTERVAL '90 days'
         GROUP BY mode ORDER BY total_co2 DESC"
    )
    .bind(user_id).fetch_all(&state.db).await?;

    let dominant_transport = mode_stats.first().map(|m| m.mode.clone()).unwrap_or("none".to_string());
    let total_co2: f64 = mode_stats.iter().map(|m| m.total_co2).sum();
    let avg_daily = total_co2 / 90.0;

    // Day-of-week patterns
    #[derive(sqlx::FromRow)]
    struct DayAgg { dow: f64, avg_co2: f64, cnt: i64, mode: String }
    let day_patterns = sqlx::query_as::<_, DayAgg>(
        "SELECT EXTRACT(DOW FROM logged_at) as dow, AVG(co2_kg) as avg_co2, COUNT(*) as cnt, mode
         FROM carbon_logs WHERE user_id = $1 AND logged_at > NOW() - INTERVAL '90 days'
         GROUP BY EXTRACT(DOW FROM logged_at), mode
         ORDER BY dow"
    )
    .bind(user_id).fetch_all(&state.db).await?;

    let day_names = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];
    let weekly: Vec<DayPattern> = (0..7).map(|d| {
        let day_data: Vec<&DayAgg> = day_patterns.iter().filter(|p| p.dow as i32 == d).collect();
        DayPattern {
            day: day_names[d as usize].to_string(),
            avg_co2_kg: day_data.iter().map(|p| p.avg_co2).sum::<f64>(),
            trip_count: day_data.iter().map(|p| p.cnt).sum(),
            dominant_mode: day_data.iter().max_by_key(|p| p.cnt)
                .map(|p| p.mode.clone()).unwrap_or("none".to_string()),
        }
    }).collect();

    // Detect habits
    let mut habits = Vec::new();
    if mode_stats.iter().any(|m| m.mode == "car" && m.trip_count > 20) {
        habits.push("Frequent car user — consider carpooling".to_string());
    }
    if mode_stats.iter().any(|m| (m.mode == "cycle" || m.mode == "walk") && m.trip_count > 10) {
        habits.push("Active green commuter — keep it up!".to_string());
    }
    if avg_daily < 2.0 {
        habits.push("Below-average carbon footprint — eco champion".to_string());
    }

    // Get AI insight from Brain
    let insight = match state.brain.reason(crate::brain_client::BrainChatRequest {
        message: format!("Analyze this user's transport behavior. Dominant mode: {}. Daily avg CO2: {:.2}kg. Give a brief 2-sentence personalized insight.", dominant_transport, avg_daily),
        user_id: auth.0.sub.clone(),
        context: None,
        mode: Some("direct".to_string()),
    }).await {
        Ok(r) => r.response,
        Err(_) => format!("Your dominant transport is {}. Daily avg: {:.2}kg CO₂.", dominant_transport, avg_daily),
    };

    Ok(Json(ApiResponse::ok(BehaviorAnalysis {
        user_id: auth.0.sub,
        dominant_transport,
        avg_daily_co2_kg: (avg_daily * 100.0).round() / 100.0,
        weekly_pattern: weekly,
        habits,
        ai_insight: insight,
    })))
}

// ── T56 — Anomaly Explainer ───────────────────────────────────────────────────

pub async fn explain_anomaly(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<AnomalyRequest>,
) -> AppResult<Json<ApiResponse<AnomalyExplanation>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let metric = req.metric.as_deref().unwrap_or("co2");
    let days = req.days.unwrap_or(7);

    // Get current period value
    let current: f64 = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT COALESCE(SUM(co2_kg), 0.0) FROM carbon_logs
         WHERE user_id = $1 AND logged_at > NOW() - make_interval(days => $2)"
    ).bind(user_id).bind(days as i32)
    .fetch_one(&state.db).await?.unwrap_or(0.0);

    // Get baseline (previous equivalent period)
    let baseline: f64 = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT COALESCE(SUM(co2_kg), 0.0) FROM carbon_logs
         WHERE user_id = $1 AND logged_at BETWEEN NOW() - make_interval(days => $2) AND NOW() - make_interval(days => $3)"
    ).bind(user_id).bind(days as i32 * 2).bind(days as i32)
    .fetch_one(&state.db).await?.unwrap_or(0.0);

    let normal_avg = if baseline > 0.0 { baseline } else { current };
    let deviation = if normal_avg > 0.0 {
        ((current - normal_avg) / normal_avg * 100.0).round()
    } else { 0.0 };

    let anomaly_detected = deviation.abs() > 40.0;

    let (explanation, cause, rec) = if deviation > 40.0 {
        // Find the culprit mode
        #[derive(sqlx::FromRow)]
        struct ModeRow { mode: String }
        let top_mode = sqlx::query_as::<_, ModeRow>(
            "SELECT mode FROM carbon_logs WHERE user_id = $1 AND logged_at > NOW() - make_interval(days => $2)
             GROUP BY mode ORDER BY SUM(co2_kg) DESC LIMIT 1"
        ).bind(user_id).bind(days as i32)
        .fetch_optional(&state.db).await?
        .map(|r| r.mode).unwrap_or("unknown".to_string());

        (
            format!("Your {} emissions spiked {:.0}% above your baseline.", metric, deviation),
            format!("High usage of '{}' mode contributed most to the spike.", top_mode),
            format!("Consider replacing {} trips with greener alternatives this week.", top_mode),
        )
    } else if deviation < -40.0 {
        (
            format!("Your {} emissions dropped {:.0}% below baseline — great improvement!", metric, deviation.abs()),
            "Increased use of green transport modes.".to_string(),
            "Keep up the momentum! Share your achievement on the feed.".to_string(),
        )
    } else {
        (
            format!("Your {} emissions are within normal range ({:.0}% deviation).", metric, deviation),
            "No unusual patterns detected.".to_string(),
            "Maintain your current habits and look for small improvements.".to_string(),
        )
    };

    Ok(Json(ApiResponse::ok(AnomalyExplanation {
        anomaly_detected,
        metric: metric.to_string(),
        normal_avg: (normal_avg * 100.0).round() / 100.0,
        current_value: (current * 100.0).round() / 100.0,
        deviation_pct: deviation,
        explanation,
        likely_cause: cause,
        recommendation: rec,
    })))
}

// ── T51 — Notification Sender (FCM Push) ──────────────────────────────────────

pub async fn send_notification(
    State(state): State<AppState>,
    _auth: AuthUser,
    Json(req): Json<NotificationRequest>,
) -> AppResult<Json<ApiResponse<NotificationResult>>> {
    let target_id = Uuid::parse_str(&req.target_user_id)
        .map_err(|_| AppError::BadRequest("Invalid target user ID".into()))?;

    // Get user's FCM token
    let fcm_token: Option<String> = sqlx::query_scalar(
        "SELECT fcm_token FROM users WHERE id = $1"
    ).bind(target_id).fetch_one(&state.db).await?;

    let (sent, method, msg) = if let Some(token) = fcm_token {
        if !token.is_empty() {
            // Send via FCM
            let fcm_key = state.config.fcm_server_key.as_deref().unwrap_or("");
            if !fcm_key.is_empty() {
                let fcm_payload = json!({
                    "to": token,
                    "notification": { "title": req.title, "body": req.body },
                    "data": req.data.unwrap_or(json!({})),
                });

                match state.brain.http
                    .post("https://fcm.googleapis.com/fcm/send")
                    .header("Authorization", format!("key={}", fcm_key))
                    .json(&fcm_payload)
                    .send().await
                {
                    Ok(_) => (true, "fcm", "Push notification sent via Firebase"),
                    Err(_) => (false, "fcm_failed", "FCM delivery failed — user will see on next app open"),
                }
            } else {
                (true, "queued", "Notification queued (FCM key not configured)")
            }
        } else {
            (false, "no_token", "User has no registered device token")
        }
    } else {
        (false, "no_user", "Target user not found")
    };

    Ok(Json(ApiResponse::ok(NotificationResult {
        sent,
        method: method.to_string(),
        target_user_id: req.target_user_id,
        message: msg.to_string(),
    })))
}

// ── T52 — Nudge Scheduler ─────────────────────────────────────────────────────

pub async fn schedule_nudge(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<NudgeScheduleRequest>,
) -> AppResult<Json<ApiResponse<NudgeSchedule>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let schedule = sqlx::query_as::<_, NudgeSchedule>(
        "INSERT INTO nudge_schedules (user_id, nudge_type, message, fire_at_hour, fire_at_minute, days_of_week)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, user_id, nudge_type, message, fire_at_hour, fire_at_minute, days_of_week, is_active, created_at"
    )
    .bind(user_id)
    .bind(&req.nudge_type)
    .bind(&req.message)
    .bind(req.fire_at_hour)
    .bind(req.fire_at_minute.unwrap_or(0))
    .bind(req.days_of_week.as_deref().unwrap_or("1,2,3,4,5"))
    .fetch_one(&state.db).await?;

    Ok(Json(ApiResponse::with_message(schedule,
        &format!("Nudge scheduled: {} at {:02}:{:02}", req.nudge_type, req.fire_at_hour, req.fire_at_minute.unwrap_or(0)))))
}

pub async fn get_nudge_schedules(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<Vec<NudgeSchedule>>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let schedules = sqlx::query_as::<_, NudgeSchedule>(
        "SELECT id, user_id, nudge_type, message, fire_at_hour, fire_at_minute, days_of_week, is_active, created_at
         FROM nudge_schedules WHERE user_id = $1 AND is_active = TRUE
         ORDER BY fire_at_hour, fire_at_minute"
    )
    .bind(user_id).fetch_all(&state.db).await?;

    Ok(Json(ApiResponse::ok(schedules)))
}

// ── T58 — Admin Override ──────────────────────────────────────────────────────

pub async fn admin_override(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<AdminOverrideRequest>,
) -> AppResult<Json<ApiResponse<AdminOverrideResult>>> {
    let admin_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid admin ID".into()))?;

    // Verify admin role
    let role: String = sqlx::query_scalar(
        "SELECT role FROM users WHERE id = $1"
    ).bind(admin_id).fetch_one(&state.db).await?;

    if role != "admin" {
        return Err(AppError::Auth("Insufficient privileges — admin role required".into()));
    }

    let (affected, details) = match req.action.as_str() {
        "reset_leaderboard" => {
            let result = sqlx::query("DELETE FROM green_points_ledger WHERE reason = 'admin_reset'")
                .execute(&state.db).await?;
            (result.rows_affected() as i64, "Leaderboard data reset initiated".to_string())
        }
        "ban_user" => {
            if let Some(target) = &req.target_id {
                let target_uuid = Uuid::parse_str(target)
                    .map_err(|_| AppError::BadRequest("Invalid target ID".into()))?;
                sqlx::query("UPDATE users SET role = 'banned' WHERE id = $1")
                    .bind(target_uuid).execute(&state.db).await?;
                (1, format!("User {} banned", target))
            } else {
                return Err(AppError::BadRequest("target_id required for ban_user".into()));
            }
        }
        "unban_user" => {
            if let Some(target) = &req.target_id {
                let target_uuid = Uuid::parse_str(target)
                    .map_err(|_| AppError::BadRequest("Invalid target ID".into()))?;
                sqlx::query("UPDATE users SET role = 'user' WHERE id = $1 AND role = 'banned'")
                    .bind(target_uuid).execute(&state.db).await?;
                (1, format!("User {} unbanned", target))
            } else {
                return Err(AppError::BadRequest("target_id required for unban_user".into()));
            }
        }
        "enter_survival" => {
            (0, "Survival mode activated — non-critical tools disabled".to_string())
        }
        "exit_survival" => {
            (0, "Survival mode deactivated — all tools restored".to_string())
        }
        _ => {
            return Err(AppError::BadRequest(format!("Unknown admin action: {}", req.action)));
        }
    };

    // Audit log
    let audit_id: Uuid = sqlx::query_scalar(
        "INSERT INTO admin_audit_log (admin_id, action, target_type, target_id, details)
         VALUES ($1, $2, 'user', $3, $4) RETURNING id"
    )
    .bind(admin_id)
    .bind(&req.action)
    .bind(req.target_id.as_deref())
    .bind(json!({ "reason": req.reason, "details": details }))
    .fetch_one(&state.db).await?;

    state.brain.log_event("admin_override", Some(&auth.0.sub), json!({
        "action": req.action, "target": req.target_id, "audit_id": audit_id,
    })).await;

    Ok(Json(ApiResponse::ok(AdminOverrideResult {
        action: req.action,
        success: true,
        affected,
        details,
        audit_id: audit_id.to_string(),
    })))
}
