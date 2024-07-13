CREATE TABLE IF NOT EXISTS nutrient (
  nutrient_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  common_name TEXT NOT NULL UNIQUE,
  unit_id UUID NOT NULL REFERENCES unit(unit_id),
  min_bound INTEGER,
  max_bound INTEGER
);