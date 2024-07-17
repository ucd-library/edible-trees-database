CREATE TABLE IF NOT EXISTS soil (
  toxicity_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  toxicity TEXT UNIQUE
);