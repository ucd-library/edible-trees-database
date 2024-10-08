CREATE TABLE IF NOT EXISTS property (
  property_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_id UUID REFERENCES pgdm_source NOT NULL,
  property_input_id UUID NOT NULL,
  species_id UUID REFERENCES species(species_id),
  species_organ_id UUID REFERENCES species_organ(species_organ_id),
  controlled_vocabulary_id UUID REFERENCES controlled_vocabulary(controlled_vocabulary_id),
  measurement_id UUID REFERENCES measurement(measurement_id),
  measurement_value FLOAT,
  usda_zone_id TEXT REFERENCES usda_zone(usda_zone_id) NOT NULL,
  data_source_publication_id UUID REFERENCES data_source_publication(data_source_publication_id),
  data_source_website_id UUID REFERENCES data_source_website(data_source_website_id),
  accessed DATE NOT NULL
);
CREATE INDEX property_source_id_idx ON property(source_id);
CREATE INDEX property_species_id_idx ON property(species_id);
CREATE INDEX property_species_organ_id_idx ON property(species_organ_id);
CREATE INDEX property_controlled_vocabulary_id_idx ON property(controlled_vocabulary_id);
CREATE INDEX property_measurement_id_idx ON property(measurement_id);
CREATE INDEX property_usda_zone_id_idx ON property(usda_zone_id);
CREATE INDEX property_data_source_publication_id_idx ON property(data_source_publication_id);
CREATE INDEX property_data_source_website_id_idx ON property(data_source_website_id);
CREATE INDEX property_accessed_idx ON property(accessed);

-- CREATE TABLE IF NOT EXISTS cv_property (
--   cv_property_id TUUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   species_organ_id UUID REFERENCES species_organ(species_organ_id),
--   species_id UUID REFERENCES species(species_id),
--   usda_zone_id TEXT REFERENCES usda_zone(usda_zone_id) NOT NULL,
--   data_source_id UUID REFERENCES data_source(data_source_id) NOT NULL,
--   controlled_vocabulary_id UUID REFERENCES controlled_vocabulary(controlled_vocabulary_id) NOT NULL,
--   source_id UUID REFERENCES pgdm_source NOT NULL
-- );

-- CREATE OR REPLACE VIEW cv_property_view AS
--   SELECT
--     cvp.cv_property_id AS cv_property_id,
--     cv.value AS value,
--     cvt.name AS type,
--     cvp.species_organ_id AS species_organ_id,
--     cvp.species_id AS species_id,
--     cvp.usda_zone_id AS usda_zone_id,
--     cvp.data_source_id AS data_source_id,
--     cvp.source_id AS source_id
--   FROM cv_property cvp
--   LEFT JOIN controlled_vocabulary cv ON cvp.controlled_vocabulary_id = cv.controlled_vocabulary_id
--   LEFT JOIN controlled_vocabulary_type cvt ON cv.controlled_vocabulary_type_id = cvt.controlled_vocabulary_type_id;

CREATE TABLE IF NOT EXISTS numeric_property (
  numeric_property_id TUUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  species_organ_id UUID REFERENCES species_organ(species_organ_id),
  species_id UUID REFERENCES species(species_id),
  usda_zone_id TEXT REFERENCES usda_zone(usda_zone_id) NOT NULL,
  data_source_id UUID REFERENCES data_source(data_source_id) NOT NULL,
  value float NOT NULL,
  source_id UUID REFERENCES pgdm_source NOT NULL
);

CREATE OR REPLACE FUNCTION check_property_values() RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.species_organ_id IS NULL AND NEW.species_id IS NULL) OR 
     (NEW.species_organ_id IS NULL AND NEW.species_id IS NOT NULL) OR 
     (NEW.species_organ_id IS NOT NULL AND NEW.species_id IS NULL) THEN
    RAISE EXCEPTION 'Either species_organ or species must be specified, but not both';
  END IF;

  IF (NEW.controlled_vocabulary_id IS NULL AND NEW.measurement_value IS NULL) OR
     (NEW.controlled_vocabulary_id IS NULL AND NEW.measurement_id IS NULL) OR 
     (NEW.controlled_vocabulary_id IS NOT NULL AND NEW.measurement_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Either a controlled_vocabulary or measurement must be specified, but not both';
  END IF;

  IF (NEW.data_source_publication_id IS NULL AND NEW.data_source_website_id IS NULL) OR
     (NEW.data_source_publication_id IS NOT NULL AND NEW.data_source_website_id IS NOT NULL) OR
     (NEW.data_source_publication_id IS NULL AND NEW.data_source_website_id IS NULL) THEN
    RAISE EXCEPTION 'Either publication or website must be specified, but not both';
  END IF;

  IF (NEW.measurement_value IS NOT NULL AND NEW.measurement_id IS NULL) OR
     (NEW.measurement_value IS NULL AND NEW.measurement_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Both measurement name and value must be specified';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_property_values_trigger
BEFORE INSERT OR UPDATE ON property
FOR EACH ROW EXECUTE FUNCTION check_property_values();

-- CREATE OR REPLACE VIEW type_zone_source_cv_property AS (
--   SELECT 
--     cvp.species_id AS species_id,
--     cvp.species_organ_id AS species_organ_id,
--     cvp.type AS type,
--     ARRAY_AG(cv.value) AS values,
--     cvp.usda_zone_id AS usda_zone_id,
--     cvp.data_source_id AS data_source_id
--   FROM cv_property_view cvp
--   LEFT JOIN controlled_vocabulary cv ON cvp.controlled_vocabulary_id = cv.controlled_vocabulary_id
--   GROUP BY cvp.species_id, cvp.species_organ_id, cvp.type, cvp.usda_zone_id, cvp.data_source_id
-- )

CREATE OR REPLACE VIEW properties_view AS
  SELECT
    p.property_id,
    g.name AS genus_name,
    s.species_id,
    s.name AS species_name,
    so.species_organ_id,
    so.name AS organ_name,
    z.usda_zone_id AS usda_zone,
    cv.value AS controlled_vocabulary_value,
    cvt.name AS controlled_vocabulary_type,
    p.value AS measurement_value,
    m.name AS measurement_name,
    u.name AS measurement_unit,
    dp.doi AS publication,
    dw.url AS website,
    COALESCE(dp.doi, dw.url) AS data_source,
    p.accessed
  FROM property p
  LEFT JOIN species s ON p.species_id = s.species_id
  LEFT JOIN genus g ON s.genus_id = g.genus_id
  LEFT JOIN species_organ so ON p.species_organ_id = so.species_organ_id
  LEFT JOIN controlled_vocabulary cv ON p.controlled_vocabulary_id = cv.controlled_vocabulary_id,
  LEFT JOIN controlled_vocabulary_type cvt ON cv.controlled_vocabulary_type_id = cvt.controlled_vocabulary_type_id
  LEFT JOIN measurement m ON p.measurement_id = m.measurement_id
  LEFT JOIN unit u ON m.unit_id = u.unit_id
  LEFT JOIN usda_zone z ON z.usda_zone_id = p.usda_zone_id
  LEFT JOIN data_source_publication dp ON p.data_source_publication_id = property.data_source_publication_id
  LEFT JOIN data_source_website dw ON p.data_source_website_id = property.data_source_website_id;



CREATE OR REPLACE VIEW species_tolerance_by_source AS 
  WITH shade AS (
    SELECT * FROM type_zone_source_cv_property WHERE type = 'shade_tolerance'
  ),
  soil AS (
    SELECT * FROM type_zone_source_cv_property WHERE type = 'soil_tolerance'
  ),
  fire AS (
    SELECT * FROM type_zone_source_cv_property WHERE type = 'fire_resilience'
  ),
  salinity AS (
    SELECT * FROM type_zone_source_cv_property WHERE type = 'salinity_tolerance'
  )
  SELECT 
    g.name AS genus_name,
    s.name AS species_name,
    shade.data_source_id AS data_source_id,
    shade.usda_zone_id AS usda_zone_id,
    shade.values AS shade_tolerances,
    soil.values AS soil_tolerances
    fire.values AS fire_resilience
  FROM species s
  LEFT JOIN genus g ON s.genus_id = g.genus_id
  LEFT JOIN soil so ON sh.species_id = so.species_id AND 
      sh.usda_zone_id = so.usda_zone_id AND
      sh.data_source_id = so.data_source_id
  LEFT JOIN soil so ON sh.species_id = so.species_id AND 
      sh.usda_zone_id = so.usda_zone_id AND
      sh.data_source_id = so.data_source_id
  LEFT JOIN fire fi ON sh.species_id = fi.species_id AND 
      sh.usda_zone_id = fi.usda_zone_id AND
      sh.data_source_id = fi.data_source_id
  LEFT JOIN salinity sa ON sh.species_id = sa.species_id AND 
      sh.usda_zone_id = sa.usda_zone_id AND
      sh.data_source_id = sa.data_source_id