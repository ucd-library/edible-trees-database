
CREATE OR REPLACE VIEW properties_view AS
  SELECT
    p.property_id,
    g.name AS genus_name,
    s.name AS species_name,
    so.name AS organ_name,
    z.usda_zone_id AS usda_zone,
    cv.value AS controlled_vocabulary_value,
    cvt.name AS controlled_vocabulary_type,
    p.value AS measurement_value,
    m.name AS measurement_name,
    u.name AS measurement_unit,
    dp.doi AS publication,
    dw.url AS website,
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

CREATE OR REPLACE VIEW properties_input AS
  SELECT
    pv.name AS genus_name,
    pv.name AS species_name, 
    pv.name AS organ_name,
    pv.usda_zone_id AS usda_zone,
    ARRAY_AG(pv.value) AS cv_values,
    ARRAY_AG(pv.value) AS num_values,
    COALESCE(pv.measurement_name, pv.controlled_vocabulary_type) AS type,
    pv.measurement_unit AS unit,
    pv.publication AS publication,
    pv.website AS website,
    pv.accessed,
  FROM properties_view pv
  GROUP BY pv.genus_name, pv.species_name, pv.organ_name, pv.usda_zone, 
          pv.measurement_name, pv.controlled_vocabulary_type, pv.unit, 
          pv.publication, pv.website, pv.accessed;

CREATE OR REPLACE FUNCTION insert_properties(
  genus_name TEXT,
  species_name TEXT,
  organ_name TEXT,
  usda_zone TEXT,
  cv_values TEXT,
  num_values TEXT,
  type TEXT,
  unit TEXT,
  publication TEXT,
  website TEXT,
  accessed DATE
) RETURNS VOID AS $$
DECLARE
  gid UUID;
  sid UUID;
  dsid UUID;
BEGIN
  SELECT get_source_id(source_name) INTO source_id;
  SELECT get_genus_id(genus_name) INTO gid;
  SELECT get_or_insert_data_access_id(publication, website, accessed) INTO dsid;

  IF( cv_values IS NOT NULL ) THEN
    FOR cv_value IN SELECT unnest(string_to_array(cv_values, ',')) AS cv_value LOOP
      INSERT INTO cv_property
      (species_id, usda_zone_id, data_source_id, controlled_vocabulary_id, source_id)
      VALUES
      (sid, usda_zone, dsid, cv_value, source_id);
    END LOOP;

  ELSE IF ( numeric_value IS NOT NULL ) THEN
    FOR numeric_value IN SELECT unnest(string_to_array(numeric_value, ',')) AS numeric_value LOOP
      INSERT INTO numeric_property
      (species_id, usda_zone_id, data_source_id, value, source_id)
      VALUES
      (sid, usda_zone, dsid, numeric_value, source_id);
    END LOOP;
  ELSE
    RAISE EXCEPTION 'Either cv_values or numeric_value must be specified';
  END IF;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for insert
CREATE OR REPLACE FUNCTION properties_input_insert_trigger()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM insert_properties(
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    organ_name := NEW.organ_name,
    usda_zone := NEW.usda_zone,
    data_source := NEW.data_source,
    cv_values := NEW.cv_values,
    numeric_value := NEW.numeric_value,
    TYPE := NEW.TYPE
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for update
CREATE OR REPLACE FUNCTION properties_input_update_trigger()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create insert trigger
CREATE TRIGGER before_insert_properties_input
INSTEAD INSERT ON properties_input
FOR EACH ROW
EXECUTE FUNCTION properties_input_insert_trigger();

-- Create update trigger
CREATE TRIGGER before_update_properties_input
BEFORE UPDATE ON properties_input
FOR EACH ROW
EXECUTE FUNCTION properties_input_update_trigger();