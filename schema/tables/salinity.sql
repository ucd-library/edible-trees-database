CREATE TABLE IF NOT EXISTS salinity (
  salinity_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  salinity TEXT UNIQUE,
);