CREATE TABLE IF NOT EXISTS measurement_property (
  measurement_measurement_property_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  property_input_id UUID NOT NULL,
  species_id UUID REFERENCES species(species_id),
  species_organ_id UUID REFERENCES species_organ(species_organ_id),
  measurement_id UUID REFERENCES measurement(measurement_id),
  measurement_value FLOAT,
  uncertainty FLOAT,
  precision FLOAT,
  publication_id UUID REFERENCES publication(publication_id),
  website_id UUID REFERENCES website(website_id),
  accessed DATE NOT NULL
);
CREATE INDEX IF NOT EXISTS measurement_property_source_id_idx ON measurement_property(pgdm_source_id);
CREATE INDEX IF NOT EXISTS measurement_property_species_id_idx ON measurement_property(species_id);
CREATE INDEX IF NOT EXISTS measurement_property_species_organ_id_idx ON measurement_property(species_organ_id);
CREATE INDEX IF NOT EXISTS measurement_property_measurement_id_idx ON measurement_property(measurement_id);
CREATE INDEX IF NOT EXISTS measurement_property_publication_id_idx ON measurement_property(publication_id);
CREATE INDEX IF NOT EXISTS measurement_property_website_id_idx ON measurement_property(website_id);
CREATE INDEX IF NOT EXISTS measurement_property_accessed_idx ON measurement_property(accessed);

-- CREATE TRIGGER check_measurement_measurement_property_values_trigger
-- BEFORE INSERT OR UPDATE ON measurement_property
-- FOR EACH ROW EXECUTE FUNCTION check_measurement_property_values();