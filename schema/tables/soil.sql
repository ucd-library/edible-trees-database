CREATE TABLE IF NOT EXISTS soil (
  soil_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE
);