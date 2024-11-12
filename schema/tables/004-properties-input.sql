
CREATE TABLE IF NOT EXISTS properties_input (
  property_input_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  genus_name TEXT NOT NULL,
  species_name TEXT NOT NULL,
  organ_name TEXT,
  usda_zone TEXT NOT NULL,
  values TEXT NOT NULL,
  type TEXT NOT NULL,
  unit TEXT,
  precision FLOAT,
  uncertainty FLOAT,
  data_source TEXT NOT NULL,
  accessed DATE NOT NULL
);

CREATE OR REPLACE FUNCTION insert_properties(
  property_input_id UUID,
  pgdm_source_name TEXT,
  genus_name TEXT,
  species_name TEXT,
  organ_name TEXT,
  usda_zones TEXT,
  "values" TEXT,
  type TEXT,
  "precision" FLOAT,
  uncertainty FLOAT,
  unit TEXT,
  data_source TEXT,
  accessed DATE
) RETURNS VOID AS $$
DECLARE
  zone TEXT;
  value TEXT;
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
        "precision" := precision,
        uncertainty := uncertainty,
        data_source := data_source,
        accessed := accessed,
        pgdm_source_name := pgdm_source_name
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
  "values" TEXT,
  type TEXT,
  unit TEXT,
  "precision" FLOAT,
  uncertainty FLOAT,
  data_source TEXT,
  accessed DATE
) RETURNS VOID AS $$
BEGIN
  DELETE FROM property WHERE property_input_id = property_input_id;
  PERFORM insert_properties(
    property_input_id := property_input_id,
    pgdm_source_name := pgdm_source_name,
    genus_name := genus_name,
    species_name := species_name,
    organ_name := organ_name,
    usda_zones := usda_zones,
    "values" := values,
    type := type,
    unit := unit,
    "precision" := precision,
    uncertainty := uncertainty,
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
  pgdm_source_name TEXT
) RETURNS VOID AS $$
DECLARE
  sid UUID;
  soid UUID;
  wdsid UUID;
  pdsid UUID;
  vid UUID;
  is_cv BOOLEAN;
  is_num BOOLEAN;
  is_tag BOOLEAN;
  is_pub BOOLEAN;
  is_web BOOLEAN;
  pgdm_source_id UUID;
BEGIN
  SELECT get_source_id(pgdm_source_name) INTO pgdm_source_id;

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

  IF is_pub IS NULL THEN
    SELECT EXISTS (
      SELECT 1 
      FROM data_source_website 
      WHERE id = data_source
    ) INTO is_web;
  END IF;

  IF is_pub IS NOT NULL THEN
    SELECT get_publication_id(data_source) INTO pdsid;
  ELSIF is_web IS NOT NULL THEN
    SELECT get_website_id(data_source) INTO wdsid;
  ELSE
    RAISE EXCEPTION 'Unknown data source: %. Could not find in publication or website tables', data_source;
  END IF;

  SELECT EXISTS (
    SELECT 1 
    FROM controlled_vocabulary_type 
    WHERE name = type
  ) INTO is_cv;

  IF is_cv IS NULL THEN
    SELECT EXISTS (
      SELECT 1 
      FROM measurement 
      WHERE name = type
    ) INTO is_num;
  END IF;

  IF is_cv IS NULL AND is_num IS NULL THEN
    SELECT EXISTS (
      SELECT 1 
      FROM tag_type
      WHERE name = type
    ) INTO is_tag;  
  END IF;

  IF is_cv THEN

    INSERT INTO measurement_property
      (pgdm_source_id, property_input_id, species_id, species_organ_id, 
      controlled_vocabulary_id, usda_zone_id, data_source_publication_id, data_source_website_id) 
    VALUES
      (pgdm_source_id, property_input_id, sid, soid, 
      get_controlled_vocabulary_id(type, value), usda_zone, pdsid, wdsid);
  ELSIF is_num THEN
    -- SELECT  INTO vid;

    INSERT INTO controlled_vocabulary_property
      (pgdm_source_id, property_input_id, species_id, species_organ_id, 
      measurement_id, measurement_value, usda_zone_id, data_source_publication_id, data_source_website_id) 
    VALUES
      (pgdm_source_id, property_input_id, sid, soid, 
      get_measurement_id(type, unit), value, usda_zone, pdsid, wdsid);

  ELSIF is_tag THEN

    INSERT INTO tag_property
      (pgdm_source_id, property_input_id, species_id, species_organ_id, 
      tag_type_id, tag_value, usda_zone_id, data_source_publication_id, data_source_website_id) 
    VALUES
      (pgdm_source_id, property_input_id, sid, soid, 
      get_tag_type_id(type), value, usda_zone, pdsid, wdsid);

  ELSE
    RAISE EXCEPTION 'Unknown type: %. The "type" column needs to be a known controlled vocabulary type or measurement, or tag type', type;
  END IF;

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
    "values" := NEW.values,
    type := NEW.type,
    unit := NEW.unit,
    data_source := NEW.data_source,
    accessed := NEW.accessed,
    pgdm_source_name := NEW.pgdm_source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
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
    "values" := NEW.values,
    type := NEW.type,
    unit := NEW.unit,
    data_source := NEW.data_source,
    accessed := NEW.accessed,
    pgdm_source_name := NEW.pgdm_source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- Create insert trigger
CREATE TRIGGER before_insert_properties_input
INSTEAD OF INSERT ON properties_input
FOR EACH ROW
EXECUTE FUNCTION properties_input_insert_trigger();

-- Create update trigger
CREATE TRIGGER before_update_properties_input
BEFORE UPDATE ON properties_input
FOR EACH ROW
EXECUTE FUNCTION properties_input_update_trigger();

-- trigger check for *_property tables
CREATE OR REPLACE FUNCTION check_property_values() RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.species_organ_id IS NULL AND NEW.species_id IS NULL) OR 
     (NEW.species_organ_id IS NULL AND NEW.species_id IS NOT NULL) OR 
     (NEW.species_organ_id IS NOT NULL AND NEW.species_id IS NULL) THEN
    RAISE EXCEPTION 'Either species_organ or species must be specified, but not both';
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