

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
  property_input_id UUID,
  source_name TEXT,
  genus_name TEXT,
  species_name TEXT,
  organ_name TEXT,
  usda_zones TEXT,
  values TEXT,
  type TEXT,
  unit TEXT,
  data_source TEXT,
  accessed DATE
) RETURNS VOID AS $$
DECLARE
  gid UUID;
  sid UUID;
  dsid UUID;
  is_cv BOOLEAN;
  is_num BOOLEAN;
BEGIN
  IF property_input_id IS NOT NULL THEN
    SELECT uuid_generate_v4() INTO property_input_id;
  END IF;

  FOR value IN SELECT unnest(string_to_array(values, ',')) AS value LOOP
    FOR zone IN SELECT unnest(string_to_array(zones, ',')) AS zone LOOP
      SELECT insert_property(
        property_input_id := property_input_id,
        genus_name := genus_name,
        species_name := species_name,
        organ_name := organ_name,
        usda_zone := zone,
        value := value,
        type := type,
        unit := unit,
        data_source := data_source,
        accessed := accessed,
        source_name := source_name
      );
    END LOOP;
  END LOOP;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_properties(
  property_input_id UUID,
  genus_name TEXT,
  species_name TEXT,
  organ_name TEXT,
  usda_zones TEXT,
  values TEXT,
  type TEXT,
  unit TEXT,
  data_source TEXT,
  accessed DATE
) RETURNS VOID AS $$
BEGIN
  DELETE FROM property WHERE property_input_id = property_input_id;
  PERFORM insert_properties(
    property_input_id := property_input_id,
    source_name := source_name,
    genus_name := genus_name,
    species_name := species_name,
    organ_name := organ_name,
    usda_zones := usda_zones,
    values := values,
    type := type,
    unit := unit,
    data_source := data_source,
    accessed := accessed
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION insert_property(
  input_id UUID,
  genus_name TEXT,
  species_name TEXT,
  organ_name TEXT,
  usda_zone TEXT,
  value TEXT,
  type TEXT,
  unit TEXT,
  data_source TEXT,
  accessed DATE,
  source_name TEXT
) RETURNS VOID AS $$
DECLARE
  sid UUID;
  soid UUID;
  wdsid UUID;
  pdsid UUID;
  vid UUID;
  is_cv BOOLEAN;
  is_num BOOLEAN;
  is_pub BOOLEAN;
  is_web BOOLEAN;
  source_id UUID;
BEGIN
  SELECT get_source_id(source_name) INTO source_id;

  IF organ_name IS NOT NULL THEN
    SELECT get_species_organ_id(genus_name, species_name, organ_name) INTO soid;
  ELSE
    SELECT get_species_id(genus_name, species_name) INTO sid;
  END IF;

  SELECT EXISTS (
    SELECT 1 
    FROM data_source_publication 
    WHERE id = data_source 
  ) INTO is_pub;

  SELECT EXISTS (
    SELECT 1 
    FROM data_source_website 
    WHERE id = data_source
  ) INTO is_web;

  IF is_pub IS NOT NULL THEN
    SELECT get_publication_data_source_id(data_source) INTO pdsid;
  ELSE IF is_web IS NOT NULL THEN
    SELECT get_website_data_source_id(data_source) INTO wdsid;
  ELSE
    RAISE EXCEPTION 'Unknown data source: %. Could not find in data_source_publication or data_source_website', data_source;
  END IF;

  SELECT EXISTS (
    SELECT 1 
    FROM controlled_vocabulary_type 
    WHERE name = type
  ) INTO is_cv;

  SELECT EXISTS (
    SELECT 1 
    FROM measurement 
    WHERE name = type
  ) INTO is_num;

  IF is_cv THEN
    SELECT get_controlled_vocabulary_id(type, value) INTO vid;

    INSERT INTO property
      (source_id, property_input_id, species_id, species_organ_id, 
      controlled_vocabulary_id, usda_zone_id, data_source_publication_id, data_source_website_id) 
    VALUES
      (source_id, property_input_id, sid, soid, 
      vid, usda_zone, pdsid, wdsid);
  ELSE IF is_num THEN
    SELECT get_measurement_id(type, unit) INTO vid;

    INSERT INTO property
      (source_id, property_input_id, species_id, species_organ_id, 
      measurement_id, measurement_value, usda_zone_id, data_source_publication_id, data_source_website_id) 
    VALUES
      (source_id, property_input_id, sid, soid, 
      vid, value, usda_zone, pdsid, wdsid);
  ELSE
    RAISE EXCEPTION 'Unknown type: %. Type needs to be a known controlled vocabulary type or measurement', type;
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
    input_id := NEW.input_id,
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    organ_name := NEW.organ_name,
    usda_zones := NEW.usda_zones,
    values := NEW.values,
    type := NEW.type,
    unit := NEW.unit,
    data_source := NEW.data_source,
    accessed := NEW.accessed,
    source_name := NEW.source_name
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for update
CREATE OR REPLACE FUNCTION properties_input_update_trigger()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM update_properties(
    input_id := NEW.input_id,
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    organ_name := NEW.organ_name,
    usda_zones := NEW.usda_zones,
    values := NEW.values,
    type := NEW.type,
    unit := NEW.unit,
    data_source := NEW.data_source,
    accessed := NEW.accessed,
    source_name := NEW.source_name
  );
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