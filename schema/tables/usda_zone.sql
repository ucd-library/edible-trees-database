-- Create table for USDAzone
CREATE TABLE IF NOT EXISTS USDAzone (
  USDAzone_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  USDAzone TEXT UNIQUE,
  temp_min NUMERIC
  temp_max NUMERIC
);

-- Create table for USDAzone_species
CREATE TABLE IF NOT EXISTS USDAzone_species (
  USDAzone_species_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  USDAzone_id UUID NOT NULL REFERENCES USDAzone(USDAzone_id),
  tolerance UUID  REFERENCES tolerance(tolerance_id),
);