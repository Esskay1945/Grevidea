/// EPIC 5: Behavioral Gamification & Community (Tools T39–T48)
/// Pure deterministic rule engine — no LLM needed for points/badges/streaks.

use crate::{auth::AuthUser, error::{AppError, AppResult}, models::*, AppState};
use axum::{extract::{Query, State}, Json};
use rand::Rng;
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

fn points_to_tier(points: i64) -> &'static str {
    match points {
        0..=499     => "Seedling",
        500..=1999  => "Sapling",
        2000..=9999 => "Tree",
        10000..=49999 => "Forest",
        _           => "Ecosystem",
    }
}

// ── T39/T40 — Green Points Balance ───────────────────────────────────────────

pub async fn get_points_balance(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<GreenPointsBalance>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let total: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COALESCE(SUM(delta), 0) FROM green_points_ledger WHERE user_id = $1"
    )
    .bind(user_id)
    .fetch_one(&state.db)
    .await?
    .unwrap_or(0);

    let lifetime: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COALESCE(SUM(delta), 0) FROM green_points_ledger WHERE user_id = $1 AND delta > 0"
    )
    .bind(user_id)
    .fetch_one(&state.db)
    .await?
    .unwrap_or(0);

    let rank: i64 = sqlx::query_scalar::<_, Option<i64>>(
        r#"SELECT COUNT(*) + 1 FROM (
               SELECT user_id, SUM(delta) as total
               FROM green_points_ledger GROUP BY user_id
               HAVING SUM(delta) > $1
           ) subq"#
    )
    .bind(total)
    .fetch_one(&state.db)
    .await?
    .unwrap_or(1);

    Ok(Json(ApiResponse::ok(GreenPointsBalance {
        user_id,
        total_points: total.max(0),
        lifetime_points: lifetime,
        tier: points_to_tier(lifetime).to_string(),
        rank,
    })))
}

// ── T41 — Achievement Engine ──────────────────────────────────────────────────

const ACHIEVEMENTS: &[(&str, &str, &str, &str)] = &[
    ("first_trip",     "First Step",        "Log your first eco-friendly trip",        "travel"),
    ("green_100",      "Century",           "Earn 100 Green Points",                    "points"),
    ("streak_7",       "Week Warrior",      "Maintain a 7-day eco-streak",              "streak"),
    ("reporter",       "Civic Guardian",    "Submit your first pollution report",        "civic"),
    ("squad_founder",  "Squad Leader",      "Create your first Eco Squad",              "social"),
    ("carbon_zero",    "Carbon Neutral Day","Achieve zero transport carbon for a day",  "carbon"),
    ("tree_100",       "Forest Starter",    "Save 100kg CO₂ total",                    "carbon"),
    ("food_7days",     "Plant-Powered",     "Log sustainable meals for 7 days",         "food"),
    ("marketplace_1",  "Circular Pioneer",  "Make your first borrow/trade",             "market"),
    ("sos_helper",     "Community Hero",    "Respond to a disaster SOS",               "civic"),
];

pub async fn check_achievements(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<Vec<Achievement>>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let total_points: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COALESCE(SUM(delta), 0) FROM green_points_ledger WHERE user_id = $1"
    ).bind(user_id).fetch_one(&state.db).await?.unwrap_or(0);

    let trip_count: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(*) FROM carbon_logs WHERE user_id = $1"
    ).bind(user_id).fetch_one(&state.db).await?.unwrap_or(0);

    let report_count: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(*) FROM pollution_reports WHERE user_id = $1"
    ).bind(user_id).fetch_one(&state.db).await?.unwrap_or(0);

    let total_saved: f64 = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT COALESCE(SUM(co2_saved_kg), 0.0) FROM carbon_logs WHERE user_id = $1"
    ).bind(user_id).fetch_one(&state.db).await?.unwrap_or(0.0);

    let mut newly_unlocked = Vec::new();

    let should_unlock = |key: &str| -> bool {
        match key {
            "first_trip"   => trip_count >= 1,
            "green_100"    => total_points >= 100,
            "reporter"     => report_count >= 1,
            "tree_100"     => total_saved >= 100.0,
            _              => false,
        }
    };

    for (key, name, desc, _cat) in ACHIEVEMENTS {
        if should_unlock(key) {
            let result = sqlx::query_as::<_, Achievement>(
                r#"INSERT INTO achievements (user_id, badge_key, badge_name, description)
                   VALUES ($1, $2, $3, $4)
                   ON CONFLICT (user_id, badge_key) DO NOTHING
                   RETURNING id, user_id, badge_key, badge_name, description, unlocked_at"#
            )
            .bind(user_id)
            .bind(key)
            .bind(name)
            .bind(desc)
            .fetch_optional(&state.db).await?;

            if let Some(a) = result { newly_unlocked.push(a); }
        }
    }

    state.brain.log_event("achievements_checked", Some(&auth.0.sub), json!({
        "newly_unlocked": newly_unlocked.len(),
    })).await;

    Ok(Json(ApiResponse::ok(newly_unlocked)))
}

pub async fn list_achievements(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<Vec<Achievement>>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;
    let achievements = sqlx::query_as::<_, Achievement>(
        "SELECT id, user_id, badge_key, badge_name, description, unlocked_at
         FROM achievements WHERE user_id = $1 ORDER BY unlocked_at DESC"
    )
    .bind(user_id)
    .fetch_all(&state.db).await?;
    Ok(Json(ApiResponse::ok(achievements)))
}

// ── T42 — Leaderboard ────────────────────────────────────────────────────────

#[derive(Serialize)]
pub struct LeaderboardEntry {
    pub rank: i64,
    pub user_id: String,
    pub display_name: String,
    pub total_points: i64,
    pub tier: String,
    pub co2_saved_kg: f64,
}

#[derive(sqlx::FromRow)]
struct LeaderboardRow {
    id: Uuid,
    display_name: String,
    total_points: Option<i64>,
    co2_saved: Option<f64>,
    rank: Option<i64>,
}

pub async fn get_leaderboard(
    State(state): State<AppState>,
    _auth: AuthUser,
    Query(p): Query<Pagination>,
) -> AppResult<Json<ApiResponse<Vec<LeaderboardEntry>>>> {
    let offset = ((p.page - 1) * p.limit) as i64;
    let rows = sqlx::query_as::<_, LeaderboardRow>(
        r#"SELECT u.id, u.display_name,
                  COALESCE(SUM(gpl.delta), 0)::bigint as total_points,
                  COALESCE(SUM(cl.co2_saved_kg), 0.0)::float8 as co2_saved,
                  (ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(gpl.delta), 0) DESC))::bigint as rank
           FROM users u
           LEFT JOIN green_points_ledger gpl ON u.id = gpl.user_id
           LEFT JOIN carbon_logs cl ON u.id = cl.user_id
           GROUP BY u.id, u.display_name
           ORDER BY total_points DESC
           LIMIT $1 OFFSET $2"#
    )
    .bind(p.limit as i64)
    .bind(offset)
    .fetch_all(&state.db).await?;

    let entries = rows.into_iter().map(|r| LeaderboardEntry {
        rank: r.rank.unwrap_or(0),
        user_id: r.id.to_string(),
        display_name: r.display_name,
        total_points: r.total_points.unwrap_or(0),
        tier: points_to_tier(r.total_points.unwrap_or(0)).to_string(),
        co2_saved_kg: r.co2_saved.unwrap_or(0.0),
    }).collect();

    Ok(Json(ApiResponse::ok(entries)))
}

// ── T43 — Streak Tracker ─────────────────────────────────────────────────────

#[derive(Serialize)]
pub struct StreakStatus {
    pub current_days: i32,
    pub longest_days: i32,
    pub is_active_today: bool,
    pub next_milestone: i32,
    pub message: String,
}

#[derive(sqlx::FromRow)]
struct StreakRow {
    current_days: i32,
    longest_days: i32,
    last_action_at: Option<chrono::DateTime<chrono::Utc>>,
}

pub async fn get_streak(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<StreakStatus>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let streak = sqlx::query_as::<_, StreakRow>(
        "SELECT current_days, longest_days, last_action_at FROM streaks WHERE user_id = $1"
    )
    .bind(user_id)
    .fetch_optional(&state.db).await?;

    let (current, longest, last_action) = streak
        .map(|s| (s.current_days, s.longest_days, s.last_action_at))
        .unwrap_or((0, 0, None));

    let is_active_today = last_action
        .map(|t| t.date_naive() == chrono::Utc::now().date_naive())
        .unwrap_or(false);

    let milestones = [3, 7, 14, 30, 60, 100];
    let next = milestones.iter().find(|&&m| m > current).copied().unwrap_or(365);

    let msg = if is_active_today {
        format!("🔥 {current}-day streak! Keep going, {more} days to the next milestone!", more = next - current)
    } else {
        "Log an eco-action today to maintain your streak!".to_string()
    };

    Ok(Json(ApiResponse::ok(StreakStatus {
        current_days: current,
        longest_days: longest,
        is_active_today,
        next_milestone: next,
        message: msg,
    })))
}

// ── T44 — Eco Squad Manager ──────────────────────────────────────────────────

pub async fn create_squad(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<CreateSquadRequest>,
) -> AppResult<Json<ApiResponse<EcoSquad>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let invite_code = format!("GRV-{:06}", rand::thread_rng().gen_range(100000..999999));

    // Step 1: Create the squad
    let squad_id: Uuid = sqlx::query_scalar(
        "INSERT INTO eco_squads (name, description, created_by, invite_code)
         VALUES ($1, $2, $3, $4) RETURNING id"
    )
    .bind(&req.name)
    .bind(&req.description)
    .bind(user_id)
    .bind(&invite_code)
    .fetch_one(&state.db).await?;

    // Step 2: Add creator as first member
    sqlx::query(
        "INSERT INTO squad_members (squad_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING"
    )
    .bind(squad_id)
    .bind(user_id)
    .execute(&state.db).await?;

    state.brain.log_event("squad_created", Some(&auth.0.sub), json!({
        "squad_id": squad_id,
        "name": req.name,
        "invite_code": invite_code,
    })).await;

    let created = sqlx::query_as::<_, EcoSquad>(
        "SELECT id, name, description, created_by, member_count, total_points, created_at
         FROM eco_squads WHERE id = $1"
    )
    .bind(squad_id)
    .fetch_one(&state.db).await?;

    Ok(Json(ApiResponse::with_message(created, &format!("Squad created! Invite code: {invite_code}"))))
}

// ── T46 — Impact Translator ───────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct ImpactRequest {
    pub co2_saved_kg: f64,
}

#[derive(Serialize)]
pub struct ImpactTranslation {
    pub co2_saved_kg: f64,
    pub tree_days: f64,
    pub car_km_equivalent: f64,
    pub phone_charges: f64,
    pub light_bulb_hours: f64,
    pub headline: String,
}

pub async fn translate_impact(
    State(_state): State<AppState>,
    _auth: AuthUser,
    Json(req): Json<ImpactRequest>,
) -> AppResult<Json<ApiResponse<ImpactTranslation>>> {
    let kg = req.co2_saved_kg;
    let tree_days = kg * 48.0;
    let car_km = kg / 0.192;
    let phone_charges = kg / 0.008;
    let bulb_hours = kg / 0.0003;

    let headline = if kg < 1.0 {
        format!("You saved {:.0}g CO₂ — equivalent to {:.0} phone charges!", kg * 1000.0, phone_charges)
    } else if kg < 10.0 {
        format!("You saved {:.1}kg CO₂ — like planting a tree for {:.0} days!", kg, tree_days)
    } else {
        format!("Amazing! {:.1}kg CO₂ saved — equivalent to not driving {:.0}km!", kg, car_km)
    };

    Ok(Json(ApiResponse::ok(ImpactTranslation {
        co2_saved_kg: kg,
        tree_days,
        car_km_equivalent: car_km,
        phone_charges,
        light_bulb_hours: bulb_hours,
        headline,
    })))
}

// ── T47 — Green Social Feed ───────────────────────────────────────────────────

pub async fn create_post(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<CreatePostRequest>,
) -> AppResult<Json<ApiResponse<SocialPost>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let post = sqlx::query_as::<_, SocialPost>(
        r#"WITH p AS (
               INSERT INTO social_posts (user_id, action_type, description, co2_saved_kg, green_points)
               VALUES ($1, $2, $3, $4, $5) RETURNING *
           )
           SELECT p.id, p.user_id, u.display_name, p.action_type, p.description,
                  p.co2_saved_kg, p.green_points, p.likes, p.created_at
           FROM p JOIN users u ON p.user_id = u.id"#
    )
    .bind(user_id)
    .bind(&req.action_type)
    .bind(&req.description)
    .bind(req.co2_saved_kg)
    .bind(req.co2_saved_kg.map(|c| (c * 100.0) as i32))
    .fetch_one(&state.db).await?;

    Ok(Json(ApiResponse::ok(post)))
}

pub async fn get_feed(
    State(state): State<AppState>,
    _auth: AuthUser,
    Query(p): Query<Pagination>,
) -> AppResult<Json<ApiResponse<Vec<SocialPost>>>> {
    let offset = ((p.page - 1) * p.limit) as i64;
    let posts = sqlx::query_as::<_, SocialPost>(
        r#"SELECT sp.id, sp.user_id, u.display_name, sp.action_type, sp.description,
                  sp.co2_saved_kg, sp.green_points, sp.likes, sp.created_at
           FROM social_posts sp JOIN users u ON sp.user_id = u.id
           ORDER BY sp.created_at DESC LIMIT $1 OFFSET $2"#
    )
    .bind(p.limit as i64)
    .bind(offset)
    .fetch_all(&state.db).await?;
    Ok(Json(ApiResponse::ok(posts)))
}

// ── T48 — Crowdfunding Manager ────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct CampaignRequest {
    pub title: String,
    pub description: String,
    pub goal_points: i32,
    pub city: Option<String>,
    pub duration_days: i32,
}

#[derive(Serialize, sqlx::FromRow)]
pub struct Campaign {
    pub id: Uuid,
    pub creator_id: Uuid,
    pub title: String,
    pub description: String,
    pub goal_points: i32,
    pub raised_points: i32,
    pub city: Option<String>,
    pub status: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub ends_at: chrono::DateTime<chrono::Utc>,
}

pub async fn create_campaign(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<CampaignRequest>,
) -> AppResult<Json<ApiResponse<Campaign>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let ends_at = chrono::Utc::now() + chrono::Duration::days(req.duration_days as i64);
    let campaign = sqlx::query_as::<_, Campaign>(
        r#"INSERT INTO crowdfunding_campaigns (creator_id, title, description, goal_points, city, ends_at)
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING id, creator_id, title, description, goal_points, raised_points, city, status, created_at, ends_at"#
    )
    .bind(user_id)
    .bind(&req.title)
    .bind(&req.description)
    .bind(req.goal_points)
    .bind(&req.city)
    .bind(ends_at)
    .fetch_one(&state.db).await?;

    Ok(Json(ApiResponse::ok(campaign)))
}

// ── T45 — Challenge Generator (Brain-Powered Quests) ──────────────────────────

pub async fn generate_daily_challenges(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<ApiResponse<Vec<DailyChallenge>>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    // Check if user already has active challenges for today
    let existing = sqlx::query_as::<_, DailyChallenge>(
        "SELECT id, user_id, title, description, category, reward_points, difficulty, expires_at, completed, created_at
         FROM daily_challenges
         WHERE user_id = $1 AND expires_at > NOW() AND completed = FALSE
         ORDER BY created_at DESC LIMIT 3"
    )
    .bind(user_id)
    .fetch_all(&state.db).await?;

    if !existing.is_empty() {
        return Ok(Json(ApiResponse::with_message(existing, "You have active challenges!")));
    }

    // Get user's weak areas from carbon_logs
    #[derive(sqlx::FromRow)]
    struct ModeStats { mode: String, total_co2: f64 }
    let weak_modes = sqlx::query_as::<_, ModeStats>(
        "SELECT mode, SUM(co2_kg) as total_co2 FROM carbon_logs
         WHERE user_id = $1 AND logged_at > NOW() - INTERVAL '30 days'
         GROUP BY mode ORDER BY total_co2 DESC LIMIT 3"
    )
    .bind(user_id).fetch_all(&state.db).await?;

    // Generate challenges based on weak areas
    let challenges_data: Vec<(&str, &str, &str, i32, &str)> = if weak_modes.iter().any(|m| m.mode == "car") {
        vec![
            ("🚌 Bus Challenge", "Take public transit for your commute today instead of driving.", "transport", 100, "medium"),
            ("🚲 Cycle Quest", "Cycle at least 3km today — log it in the app!", "transport", 150, "hard"),
            ("🥗 Green Plate", "Have a fully plant-based lunch today.", "food", 50, "easy"),
        ]
    } else if weak_modes.iter().any(|m| m.mode == "motorbike") {
        vec![
            ("🚶 Walk It Out", "Walk any distance over 1km instead of riding today.", "transport", 75, "easy"),
            ("🗳️ Civic Voice", "Submit a pollution report for any issue you spot.", "civic", 80, "medium"),
            ("📚 Climate Learn", "Complete 3 learning cards today.", "social", 60, "easy"),
        ]
    } else {
        vec![
            ("🌱 Meatless Monday", "Skip all meat today and log your plant-based meals.", "food", 100, "medium"),
            ("♻️ Share Economy", "Lend or borrow an item on the marketplace.", "social", 120, "medium"),
            ("🏃 Eco Sprint", "Log 5000+ steps today via the lifestyle tracker.", "transport", 80, "easy"),
        ]
    };

    let expires = chrono::Utc::now() + chrono::Duration::hours(24);
    let mut created_challenges = Vec::new();

    for (title, desc, cat, points, diff) in &challenges_data {
        let challenge = sqlx::query_as::<_, DailyChallenge>(
            "INSERT INTO daily_challenges (user_id, title, description, category, reward_points, difficulty, expires_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING id, user_id, title, description, category, reward_points, difficulty, expires_at, completed, created_at"
        )
        .bind(user_id).bind(title).bind(desc).bind(cat).bind(points).bind(diff).bind(expires)
        .fetch_one(&state.db).await?;
        created_challenges.push(challenge);
    }

    state.brain.log_event("challenges_generated", Some(&auth.0.sub), json!({
        "count": created_challenges.len(),
        "categories": challenges_data.iter().map(|c| c.2).collect::<Vec<_>>(),
    })).await;

    Ok(Json(ApiResponse::with_message(created_challenges, "3 new daily challenges generated!")))
}

pub async fn complete_challenge(
    State(state): State<AppState>,
    auth: AuthUser,
    axum::extract::Path(challenge_id): axum::extract::Path<Uuid>,
) -> AppResult<Json<ApiResponse<serde_json::Value>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    // Verify ownership and active
    let challenge = sqlx::query_as::<_, DailyChallenge>(
        "SELECT id, user_id, title, description, category, reward_points, difficulty, expires_at, completed, created_at
         FROM daily_challenges WHERE id = $1 AND user_id = $2"
    )
    .bind(challenge_id).bind(user_id)
    .fetch_optional(&state.db).await?
    .ok_or_else(|| AppError::NotFound("Challenge not found".into()))?;

    if challenge.completed {
        return Err(AppError::BadRequest("Challenge already completed".into()));
    }

    // Mark complete and award points
    sqlx::query("UPDATE daily_challenges SET completed = TRUE, completed_at = NOW() WHERE id = $1")
        .bind(challenge_id).execute(&state.db).await?;

    sqlx::query("INSERT INTO green_points_ledger (user_id, delta, reason, reference_id) VALUES ($1, $2, $3, $4)")
        .bind(user_id).bind(challenge.reward_points)
        .bind(format!("Completed challenge: {}", challenge.title))
        .bind(challenge_id)
        .execute(&state.db).await?;

    Ok(Json(ApiResponse::with_message(json!({
        "completed": true, "points_earned": challenge.reward_points
    }), &format!("🎉 Challenge complete! +{} Green Points!", challenge.reward_points))))
}
