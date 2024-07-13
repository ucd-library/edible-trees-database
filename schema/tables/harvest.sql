CREATE TABLE IF NOT EXISTS harvest_period (
  harvest_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  harvest_period TEXT UNIQUE,
);