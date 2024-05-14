CREATE TABLE IF NOT EXISTS qa_user (
  qa_user UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  casid TEXT NOT NULL UNIQUE,
  email TEXT UNIQUE
);

CREATE TABLE IF NOT EXISTS species_organ_nutrient_qa (
  species_organ_nutrient_qa UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  species_organ_nutrient_id UUID NOT NULL REFERENCES species_organ_nutrient(species_organ_nutrient_id),
  qa_user_id UUID NOT NULL REFERENCES qa_user(qa_user),
  status qa_status NOT NULL,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);