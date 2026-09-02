-- Grevidea Complete Database Schema
-- PostgreSQL + PostGIS (Supabase)
-- Run this migration in your Supabase SQL Editor

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- ─── Users & Auth ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           TEXT UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,
    display_name    TEXT NOT NULL,
    role            TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
    eco_persona     TEXT,
    fcm_token       TEXT,
    bio             TEXT,
    avatar_url      TEXT,
    is_verified     BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Carbon Footprint ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS carbon_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mode            TEXT NOT NULL,
    distance_km     DOUBLE PRECISION NOT NULL,
    co2_kg          DOUBLE PRECISION NOT NULL,
    co2_saved_kg    DOUBLE PRECISION NOT NULL DEFAULT 0,
    green_points    INTEGER NOT NULL DEFAULT 0,
    source          TEXT DEFAULT 'manual',
    logged_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS carbon_budgets (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    monthly_cap_kg  DOUBLE PRECISION NOT NULL,
    month_year      TEXT NOT NULL, -- "2026-08"
    used_kg         DOUBLE PRECISION NOT NULL DEFAULT 0,
    UNIQUE(user_id, month_year)
);

CREATE TABLE IF NOT EXISTS food_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    food_name       TEXT NOT NULL,
    quantity_grams  DOUBLE PRECISION NOT NULL,
    co2_kg          DOUBLE PRECISION NOT NULL,
    water_liters    DOUBLE PRECISION NOT NULL DEFAULT 0,
    origin          TEXT,
    logged_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── AQI & Civic ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS aqi_readings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id      TEXT NOT NULL,
    city            TEXT NOT NULL,
    aqi             INTEGER NOT NULL,
    pm25            DOUBLE PRECISION DEFAULT 0,
    pm10            DOUBLE PRECISION DEFAULT 0,
    no2             DOUBLE PRECISION DEFAULT 0,
    so2             DOUBLE PRECISION DEFAULT 0,
    co              DOUBLE PRECISION DEFAULT 0,
    o3              DOUBLE PRECISION DEFAULT 0,
    category        TEXT NOT NULL,
    location        GEOGRAPHY(POINT, 4326),
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pollution_reports (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    report_type     TEXT NOT NULL,
    description     TEXT NOT NULL,
    severity        SMALLINT NOT NULL CHECK (severity BETWEEN 1 AND 5),
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    location        GEOGRAPHY(POINT, 4326) GENERATED ALWAYS AS (
                        ST_MakePoint(longitude, latitude)::geography
                    ) STORED,
    status          TEXT NOT NULL DEFAULT 'open',
    photo_url       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS sos_requests (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    disaster_type   TEXT NOT NULL,
    description     TEXT NOT NULL,
    needs           JSONB NOT NULL DEFAULT '[]',
    people_count    INTEGER NOT NULL DEFAULT 1,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    location        GEOGRAPHY(POINT, 4326) GENERATED ALWAYS AS (
                        ST_MakePoint(longitude, latitude)::geography
                    ) STORED,
    status          TEXT NOT NULL DEFAULT 'active',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS disaster_risk_predictions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    city            TEXT NOT NULL,
    risk_type       TEXT NOT NULL,  -- "flood"|"fire"|"drought"|"heatwave"
    risk_score      DOUBLE PRECISION NOT NULL CHECK (risk_score BETWEEN 0 AND 1),
    risk_label      TEXT NOT NULL,  -- "Low"|"Moderate"|"High"|"Critical"
    factors         JSONB NOT NULL DEFAULT '{}',
    valid_until     TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Gamification ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS green_points_ledger (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delta           INTEGER NOT NULL,  -- positive = earned, negative = spent
    reason          TEXT NOT NULL,
    reference_id    UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS achievements (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_key       TEXT NOT NULL,
    badge_name      TEXT NOT NULL,
    description     TEXT NOT NULL,
    unlocked_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, badge_key)
);

CREATE TABLE IF NOT EXISTS streaks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    current_days    INTEGER NOT NULL DEFAULT 0,
    longest_days    INTEGER NOT NULL DEFAULT 0,
    last_action_at  TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS eco_squads (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    description     TEXT,
    created_by      UUID NOT NULL REFERENCES users(id),
    invite_code     TEXT UNIQUE NOT NULL,
    member_count    INTEGER NOT NULL DEFAULT 1,
    total_points    BIGINT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS squad_members (
    squad_id        UUID NOT NULL REFERENCES eco_squads(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY(squad_id, user_id)
);

CREATE TABLE IF NOT EXISTS challenges (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,  -- NULL = global
    squad_id        UUID REFERENCES eco_squads(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    description     TEXT NOT NULL,
    challenge_type  TEXT NOT NULL,
    target_value    DOUBLE PRECISION NOT NULL,
    reward_points   INTEGER NOT NULL,
    starts_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at         TIMESTAMPTZ NOT NULL,
    is_completed    BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS crowdfunding_campaigns (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id      UUID NOT NULL REFERENCES users(id),
    title           TEXT NOT NULL,
    description     TEXT NOT NULL,
    goal_points     INTEGER NOT NULL,
    raised_points   INTEGER NOT NULL DEFAULT 0,
    city            TEXT,
    status          TEXT NOT NULL DEFAULT 'active',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at         TIMESTAMPTZ NOT NULL
);

-- ─── Marketplace & Circular Economy ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS marketplace_listings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    seller_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    description     TEXT NOT NULL,
    listing_type    TEXT NOT NULL CHECK (listing_type IN ('borrow','trade','donate','carbon_credit')),
    carbon_credits  DOUBLE PRECISION,
    price_points    INTEGER,
    is_available    BOOLEAN NOT NULL DEFAULT TRUE,
    latitude        DOUBLE PRECISION,
    longitude       DOUBLE PRECISION,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS borrow_requests (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    listing_id      UUID NOT NULL REFERENCES marketplace_listings(id),
    borrower_id     UUID NOT NULL REFERENCES users(id),
    status          TEXT NOT NULL DEFAULT 'pending',
    message         TEXT,
    co2_avoided_kg  DOUBLE PRECISION DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    returned_at     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS carpool_listings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id       UUID NOT NULL REFERENCES users(id),
    origin          TEXT NOT NULL,
    destination     TEXT NOT NULL,
    departure_at    TIMESTAMPTZ NOT NULL,
    seats_available INTEGER NOT NULL,
    price_points    INTEGER DEFAULT 0,
    co2_saved_per_rider DOUBLE PRECISION DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'open',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS gig_listings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    poster_id       UUID NOT NULL REFERENCES users(id),
    title           TEXT NOT NULL,
    description     TEXT NOT NULL,
    gig_type        TEXT NOT NULL,
    skills_required TEXT[],
    reward_points   INTEGER NOT NULL,
    city            TEXT,
    status          TEXT NOT NULL DEFAULT 'open',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Social Feed ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS social_posts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action_type     TEXT NOT NULL,
    description     TEXT NOT NULL,
    co2_saved_kg    DOUBLE PRECISION,
    green_points    INTEGER,
    media_url       TEXT,
    likes           INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS post_likes (
    post_id         UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY(post_id, user_id)
);

CREATE TABLE IF NOT EXISTS social_connections (
    follower_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY(follower_id, following_id)
);

-- ─── Learning & Micro-cards ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS learning_cards (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,
    category        TEXT NOT NULL,
    difficulty      TEXT NOT NULL DEFAULT 'beginner',
    points_reward   INTEGER NOT NULL DEFAULT 5,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_card_progress (
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    card_id         UUID NOT NULL REFERENCES learning_cards(id) ON DELETE CASCADE,
    completed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY(user_id, card_id)
);

-- ─── RTI / Civic Actions ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS rti_drafts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    violation_type  TEXT NOT NULL,
    authority       TEXT NOT NULL,
    description     TEXT NOT NULL,
    draft_text      TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'draft',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Indexes for performance ──────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_carbon_logs_user_id ON carbon_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_carbon_logs_logged_at ON carbon_logs(logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_aqi_readings_city ON aqi_readings(city);
CREATE INDEX IF NOT EXISTS idx_aqi_readings_recorded_at ON aqi_readings(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_pollution_reports_location ON pollution_reports USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_sos_requests_location ON sos_requests USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_type ON marketplace_listings(listing_type);
CREATE INDEX IF NOT EXISTS idx_social_posts_user_id ON social_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_social_posts_created_at ON social_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_green_points_user_id ON green_points_ledger(user_id);
