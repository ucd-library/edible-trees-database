CREATE TABLE IF NOT EXISTS common_name (
  common_name_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_id UUID REFERENCES pgdm_source NOT NULL,
  species_id UUID NOT NULL REFERENCES species(species_id),
  name TEXT NOT NULL UNIQUE
);