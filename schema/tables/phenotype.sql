
CREATE TABLE IF NOT EXISTS flower_color (
  flowercolor_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS bloom_period (
  bloom_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bloom_period TEXT UNIQUE,
);

CREATE TABLE IF NOT EXISTS harvest_period (
  harvest_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  harvest_period TEXT UNIQUE,
);

-- phenotype relationship table
CREATE TABLE IF NOT EXISTS phenotype (
  phenotype UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  species_id UUID NOT NULL REFERENCES species(species_id),
  flower_color UUID  REFERENCES color(flower_color_id),
  bloom UUID  REFERENCES salinity(bloom_id),
  harvest UUID  REFERENCES harvest (harvest_id),
  coppice BOOLEAN,
  alleopathy BOOLEAN
  leaf_retention BOOLEAN
);