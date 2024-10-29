CREATE TABLE IF NOT EXISTS controlled_vocabulary_property (
  property_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  property_input_id UUID NOT NULL,
  species_id UUID REFERENCES species(species_id),
  species_organ_id UUID REFERENCES species_organ(species_organ_id),
  controlled_vocabulary_id UUID REFERENCES controlled_vocabulary(controlled_vocabulary_id),
  usda_zone_id TEXT REFERENCES usda_zone(usda_zone_id) NOT NULL,
  data_source_publication_id UUID REFERENCES data_source_publication(data_source_publication_id),
  data_source_website_id UUID REFERENCES data_source_website(data_source_website_id),
  accessed DATE NOT NULL
);
CREATE INDEX property_source_id_idx ON property(pgdm_source_id);
CREATE INDEX property_species_id_idx ON property(species_id);
CREATE INDEX property_species_organ_id_idx ON property(species_organ_id);
CREATE INDEX property_controlled_vocabulary_id_idx ON property(controlled_vocabulary_id);
CREATE INDEX property_measurement_id_idx ON property(measurement_id);
CREATE INDEX property_usda_zone_id_idx ON property(usda_zone_id);
CREATE INDEX property_data_source_publication_id_idx ON property(data_source_publication_id);
CREATE INDEX property_data_source_website_id_idx ON property(data_source_website_id);
CREATE INDEX property_accessed_idx ON property(accessed);

CREATE TRIGGER check_controlled_vocabulary_values_trigger
BEFORE INSERT OR UPDATE ON controlled_vocabulary_property
FOR EACH ROW EXECUTE FUNCTION check_property_values();