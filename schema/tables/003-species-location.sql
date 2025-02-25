CREATE TABLE IF NOT EXISTS species_location (
  species_location_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  species_id UUID REFERENCES species NOT NULL,
  type TEXT NOT NULL,
  geom GEOMETRY(Geometry, 4326) NOT NULL,
  UNIQUE (species_id, type)
);