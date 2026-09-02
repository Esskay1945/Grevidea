-- ═══════════════════════════════════════════════════════════════════════════════
-- Grevidea Migration 002: Feature Expansion Tables
-- Adds 8 tables for the 25 remaining features.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── Green Zones (parks/forests imported from OSM) ─────────────────────────────
CREATE TABLE IF NOT EXISTS green_zones (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    zone_type       TEXT NOT NULL DEFAULT 'park',  -- park | forest | garden | wetland
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    area_sqm        DOUBLE PRECISION DEFAULT 0,
    aqi_estimate    INT DEFAULT 40,
    description     TEXT DEFAULT '',
    osm_id          TEXT,
    city            TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Daily Challenges (AI-generated quests) ────────────────────────────────────
CREATE TABLE IF NOT EXISTS daily_challenges (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    description     TEXT NOT NULL,
    category        TEXT NOT NULL DEFAULT 'transport', -- transport | food | civic | social
    reward_points   INT NOT NULL DEFAULT 50,
    difficulty      TEXT NOT NULL DEFAULT 'medium',    -- easy | medium | hard
    expires_at      TIMESTAMPTZ NOT NULL,
    completed       BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Municipal Green Projects (participatory budgeting) ────────────────────────
CREATE TABLE IF NOT EXISTS municipal_projects (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ward_id         TEXT NOT NULL,
    title           TEXT NOT NULL,
    description     TEXT NOT NULL,
    budget_points   INT NOT NULL DEFAULT 0,
    votes_count     INT NOT NULL DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'open', -- open | funded | completed
    city            TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS municipal_votes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    project_id      UUID NOT NULL REFERENCES municipal_projects(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, project_id)
);

-- ── Seller Certificates (automated verification) ─────────────────────────────
CREATE TABLE IF NOT EXISTS seller_certificates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cert_type       TEXT NOT NULL,       -- ISO_14001 | BIS_ECOMARK | FSC | ORGANIC | FAIR_TRADE
    cert_number     TEXT NOT NULL,
    issuer          TEXT NOT NULL,
    expiry_date     DATE NOT NULL,
    document_hash   TEXT NOT NULL,       -- SHA-256 for tamper detection
    status          TEXT NOT NULL DEFAULT 'pending', -- pending | verified | rejected | expired
    rejection_reason TEXT,
    verified_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Carbon Offset Projects (verified registry) ───────────────────────────────
CREATE TABLE IF NOT EXISTS offset_projects (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    location        TEXT NOT NULL,
    project_type    TEXT NOT NULL,     -- afforestation | solar | wind | biogas | cookstove
    cost_per_kg     DOUBLE PRECISION NOT NULL DEFAULT 0.50,
    total_capacity_kg DOUBLE PRECISION NOT NULL DEFAULT 100000.0,
    used_capacity_kg  DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    certifier       TEXT NOT NULL,     -- Gold Standard | Verra | CDM
    description     TEXT NOT NULL DEFAULT '',
    is_verified     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Nudge Schedules (JITAI timing) ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS nudge_schedules (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    nudge_type      TEXT NOT NULL DEFAULT 'commute',
    message         TEXT NOT NULL DEFAULT '',
    fire_at_hour    INT NOT NULL DEFAULT 8,      -- hour of day (0-23)
    fire_at_minute  INT NOT NULL DEFAULT 0,
    days_of_week    TEXT NOT NULL DEFAULT '1,2,3,4,5',  -- Mon-Fri
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    last_fired_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Admin Audit Log ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS admin_audit_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action          TEXT NOT NULL,
    target_type     TEXT,
    target_id       TEXT,
    details         JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Lifestyle Logs (auto-inferred from pedometer / health apps) ──────────────
CREATE TABLE IF NOT EXISTS lifestyle_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    step_count      INT NOT NULL DEFAULT 0,
    active_minutes  INT NOT NULL DEFAULT 0,
    cycling_minutes INT NOT NULL DEFAULT 0,
    avoided_co2_kg  DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    green_points    INT NOT NULL DEFAULT 0,
    source          TEXT NOT NULL DEFAULT 'in_app',  -- in_app | strava | fitbit | garmin | health_connect
    logged_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Seed: Verified Offset Projects ───────────────────────────────────────────
INSERT INTO offset_projects (name, location, project_type, cost_per_kg, total_capacity_kg, certifier, description) VALUES
    ('Sundarbans Mangrove Restoration', 'West Bengal, India', 'afforestation', 0.35, 500000, 'Gold Standard', 'Restoring degraded mangrove ecosystems in the Sundarbans delta, protecting coastal communities from cyclones while sequestering carbon.'),
    ('Gujarat Solar Cookstove Initiative', 'Gujarat, India', 'cookstove', 0.20, 200000, 'Gold Standard', 'Distributing efficient solar cookstoves to rural households, displacing biomass burning.'),
    ('Madhya Pradesh Community Forestry', 'Madhya Pradesh, India', 'afforestation', 0.45, 750000, 'Verra', 'Community-managed afforestation across 5000 hectares of degraded forest land.'),
    ('Tamil Nadu Wind Energy', 'Tamil Nadu, India', 'wind', 0.15, 1000000, 'CDM', 'Grid-connected wind power displacing coal-fired electricity generation.'),
    ('Rajasthan Biogas Programme', 'Rajasthan, India', 'biogas', 0.30, 300000, 'Gold Standard', 'Converting cattle waste into biogas for cooking fuel, eliminating wood burning.'),
    ('Himachal Pradesh Watershed', 'Himachal Pradesh, India', 'afforestation', 0.50, 400000, 'Verra', 'Watershed restoration and tree planting across Himalayan catchment areas.'),
    ('Kerala Bamboo Carbon Sink', 'Kerala, India', 'afforestation', 0.40, 250000, 'Gold Standard', 'Fast-growing bamboo plantations on marginal lands sequestering 12x more CO₂ than traditional forests.'),
    ('Odisha Clean Cookstove Project', 'Odisha, India', 'cookstove', 0.25, 350000, 'CDM', 'Replacing traditional chulhas with clean-burning stoves in tribal communities.')
ON CONFLICT DO NOTHING;

-- ── Seed: Green Zones (sample parks for major Indian cities) ─────────────────
INSERT INTO green_zones (name, zone_type, latitude, longitude, area_sqm, aqi_estimate, city, description) VALUES
    ('Lodhi Garden', 'park', 28.5917, 77.2198, 360000, 38, 'Delhi', 'Historic Mughal-era garden with dense tree cover and low pollution.'),
    ('Cubbon Park', 'park', 12.9763, 77.5929, 1200000, 32, 'Bangalore', 'Sprawling 300-acre green lung in the heart of Bangalore.'),
    ('Sanjay Gandhi National Park', 'forest', 19.2147, 72.9106, 87000000, 25, 'Mumbai', 'Protected forest within city limits — cleanest air in Mumbai.'),
    ('Eco Park', 'park', 22.6015, 88.4653, 190000, 35, 'Kolkata', 'Modern ecological park with urban forest and wetland areas.'),
    ('Lalbagh Botanical Garden', 'garden', 12.9507, 77.5848, 970000, 30, 'Bangalore', '240-year-old botanical garden with 1800+ plant species.'),
    ('Deer Park', 'park', 28.5536, 77.1994, 62000, 42, 'Delhi', 'Green refuge in South Delhi with deer enclosures and lake.'),
    ('Aarey Colony', 'forest', 19.1566, 72.8674, 12000000, 28, 'Mumbai', 'Urban forest and tribal area — critical Mumbai green corridor.'),
    ('Nehru Park', 'park', 28.5894, 77.1890, 80000, 40, 'Delhi', 'Well-maintained park along Chanakyapuri diplomatic enclave.'),
    ('Hussain Sagar Lake Park', 'park', 17.4239, 78.4738, 230000, 45, 'Hyderabad', 'Lakeside green belt with walking paths and cleaner air zones.'),
    ('Guindy National Park', 'forest', 13.0067, 80.2206, 2700000, 33, 'Chennai', 'One of the smallest national parks — a green island within Chennai.')
ON CONFLICT DO NOTHING;

-- ── Seed: Municipal Green Projects ───────────────────────────────────────────
INSERT INTO municipal_projects (ward_id, title, description, budget_points, city) VALUES
    ('DEL-W14', 'Solar Street Lights — Saket', 'Install 200 solar-powered street lights replacing diesel generators.', 50000, 'Delhi'),
    ('BLR-W03', 'Community Composting Hub — Koramangala', 'Set up a 500kg/day composting facility for wet waste.', 35000, 'Bangalore'),
    ('MUM-W22', 'Rainwater Harvesting — Andheri', 'Install rooftop rainwater harvesting across 50 municipal buildings.', 75000, 'Mumbai'),
    ('KOL-W08', 'Urban Wetland Restoration — Salt Lake', 'Restore 10-acre degraded wetland as flood buffer and bird habitat.', 60000, 'Kolkata'),
    ('CHN-W15', 'Cycle Lane — T. Nagar to Guindy', 'Build a 5km protected cycle lane connecting two major hubs.', 45000, 'Chennai')
ON CONFLICT DO NOTHING;
