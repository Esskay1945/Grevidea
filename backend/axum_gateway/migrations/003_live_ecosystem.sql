ALTER TABLE carpool_listings ADD COLUMN IF NOT EXISTS pickup_lat DOUBLE PRECISION;
ALTER TABLE carpool_listings ADD COLUMN IF NOT EXISTS pickup_lon DOUBLE PRECISION;
ALTER TABLE carpool_listings ADD COLUMN IF NOT EXISTS route_geometry JSONB;
CREATE TABLE IF NOT EXISTS carpool_bookings (
 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
 listing_id UUID NOT NULL REFERENCES carpool_listings(id),
 passenger_id UUID NOT NULL REFERENCES users(id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 UNIQUE(listing_id, passenger_id)
);
CREATE TABLE IF NOT EXISTS mutual_aid (
 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
 user_id UUID NOT NULL REFERENCES users(id),
 category TEXT NOT NULL,
 description TEXT NOT NULL,
 latitude DOUBLE PRECISION NOT NULL CHECK(latitude BETWEEN -90 AND 90),
 longitude DOUBLE PRECISION NOT NULL CHECK(longitude BETWEEN -180 AND 180),
 status TEXT NOT NULL DEFAULT 'open',
 coordinated_by UUID REFERENCES users(id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE sos_requests ADD COLUMN IF NOT EXISTS battery_percent INTEGER CHECK(battery_percent BETWEEN 0 AND 100);
ALTER TABLE sos_requests ADD COLUMN IF NOT EXISTS street_address TEXT;
CREATE TABLE IF NOT EXISTS habit_claims (
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 day DATE NOT NULL,
 habit_id TEXT NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 PRIMARY KEY(user_id,day,habit_id)
);
CREATE TABLE IF NOT EXISTS reward_redemptions (
 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 reward_id TEXT NOT NULL,
 cost INTEGER NOT NULL CHECK(cost>0),
 status TEXT NOT NULL DEFAULT 'pending_fulfillment',
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE carbon_logs ADD COLUMN IF NOT EXISTS client_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS carbon_logs_client_id ON carbon_logs(user_id,client_id) WHERE client_id IS NOT NULL;
