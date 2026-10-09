CREATE TABLE IF NOT EXISTS delivery_jobs (
 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 entity_id UUID NOT NULL,
 kind TEXT NOT NULL CHECK(kind IN ('sos','civic','reward')),
 payload JSONB NOT NULL,
 status TEXT NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','processing','blocked','accepted','delivered','failed','dead_letter','cancelled')),
 attempts INTEGER NOT NULL DEFAULT 0,
 next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 lease_until TIMESTAMPTZ,
 provider_id TEXT,
 last_error TEXT,
 receipt JSONB,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 UNIQUE(kind,entity_id)
);
CREATE INDEX IF NOT EXISTS delivery_jobs_pending ON delivery_jobs(next_attempt_at) WHERE status IN ('queued','blocked','processing','failed');
CREATE TABLE IF NOT EXISTS trusted_contacts (
 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 name TEXT NOT NULL,
 phone TEXT NOT NULL,
 consent_attested BOOLEAN NOT NULL CHECK(consent_attested),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 UNIQUE(user_id,phone)
);
CREATE TABLE IF NOT EXISTS activity_events (
 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 client_id TEXT NOT NULL,
 category TEXT NOT NULL CHECK(category IN ('Transport','Energy','Food','Waste')),
 title TEXT NOT NULL,
 subtitle TEXT NOT NULL DEFAULT '',
 co2_delta_kg DOUBLE PRECISION NOT NULL,
 occurred_at TIMESTAMPTZ NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 UNIQUE(user_id,client_id)
);
CREATE INDEX IF NOT EXISTS activity_events_history ON activity_events(user_id,occurred_at);
CREATE TABLE IF NOT EXISTS baseline_profiles (
 user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
 profile JSONB NOT NULL,
 completed BOOLEAN NOT NULL DEFAULT FALSE,
 updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS provider_receipts (
 id TEXT PRIMARY KEY,
 delivery_id UUID NOT NULL REFERENCES delivery_jobs(id),
 received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE OR REPLACE FUNCTION notify_grevidea_live() RETURNS TRIGGER AS $$
BEGIN
 PERFORM pg_notify('grevidea_live', 'changed');
 RETURN NULL;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS mutual_aid_live ON mutual_aid;
CREATE TRIGGER mutual_aid_live AFTER INSERT OR UPDATE OR DELETE ON mutual_aid FOR EACH STATEMENT EXECUTE FUNCTION notify_grevidea_live();
DROP TRIGGER IF EXISTS carpool_live ON carpool_listings;
CREATE TRIGGER carpool_live AFTER INSERT OR UPDATE OR DELETE ON carpool_listings FOR EACH STATEMENT EXECUTE FUNCTION notify_grevidea_live();

-- Bring existing gateway trips into shared Tracker history without granting points again.
INSERT INTO activity_events(user_id,client_id,category,title,subtitle,co2_delta_kg,occurred_at)
SELECT user_id,COALESCE(client_id,'server-trip-'||id::text),'Transport',mode||' trip',
       distance_km::text||' km; imported gateway trip',-co2_saved_kg,logged_at
FROM carbon_logs
ON CONFLICT(user_id,client_id) DO NOTHING;
