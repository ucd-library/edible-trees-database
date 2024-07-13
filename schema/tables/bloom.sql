CREATE TABLE IF NOT EXISTS bloom_period (
  bloom_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bloom_period TEXT UNIQUE,
);