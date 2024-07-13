CREATE TABLE IF NOT EXISTS genus (
  genus_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  genus TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS species (
  species_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  genus_id UUID NOT NULL REFERENCES genus(genus_id),
);

CREATE TABLE IF NOT EXISTS fire (
  fire_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  fire TEXT UNIQUE
);

CREATE TABLE IF NOT EXISTS soil (
  soil_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  soil TEXT UNIQUE
);

CREATE TABLE IF NOT EXISTS shade (
  shade_tolerance UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
   shade TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS salinity (
  salinity_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  salinity TEXT UNIQUE,
);

-- have not added the USDA zones yet, i want to fully understand the structure  before adding it
-- relationship table between species and all tolerances
CREATE TABLE IF NOT EXISTS tolerance (
  tolerance UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  species_id UUID NOT NULL REFERENCES species(species_id),
  fire UUID  REFERENCES fire(fire_id),
  salinity UUID  REFERENCES salinity(salinity_id),
  shade UUID  REFERENCES shade(shade_id),
  soil UUID  REFERENCES soil(soil_id),
  precipitation_max INTEGER,
  precipitation_min INTEGER,
  frost_min INTEGER,
  frost_max INTEGER
);