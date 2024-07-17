 CREATE TABLE IF NOT EXISTS notes (
  notes_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  notes TEXT UNIQUE,
  species_id UUID NOT NULL REFERENCES species(species_id),
    species_organ_nutrient_id UUID REFERENCES species_organ_nutrient(species_organ_nutrient_id),
    phenotype_id UUID REFERENCES phenotype(phenotype_id),
    tolerance_id UUID REFERENCES tolerance(tolerance_id),
);
