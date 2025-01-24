
CREATE TABLE IF NOT EXISTS properties_input (
  property_input_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_name TEXT REFERENCES pgdm_source(name) NOT NULL,
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
  accessed DATE NOT NULL,
  comments TEXT
);

CREATE OR REPLACE FUNCTION insert_properties(
  property_input_id UUID,
  pgdm_source_name TEXT,
  genus_name TEXT,
  species_name TEXT,
  organ_name TEXT,
  usda_zone TEXT,
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
    FOR zone IN SELECT unnest(string_to_array(usda_zone, ',')) AS zone LOOP
      PERFORM insert_property(
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
  usda_zone TEXT,
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
    usda_zone := usda_zone,
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
  property_input_id UUID,
  genus_name TEXT,
  species_name TEXT,
  organ_name TEXT,
  usda_zone TEXT,
  value TEXT,
  type TEXT,
  unit TEXT,
  "precision" FLOAT,
  uncertainty FLOAT,
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

  SELECT get_species_id(genus_name, species_name) INTO sid;
  IF organ_name IS NOT NULL THEN
    SELECT get_species_organ_id(genus_name, species_name, organ_name) INTO soid;
  END IF;

  SELECT EXISTS (
    SELECT true 
    FROM publication p 
    WHERE p.doi = data_source 
  ) INTO is_pub;

  IF NOT is_pub THEN
    SELECT EXISTS (
      SELECT true 
      FROM website w
      WHERE w.url = data_source
    ) INTO is_web;
  END IF;

  IF is_pub THEN
    SELECT get_publication_id(data_source) INTO pdsid;
  ELSIF is_web THEN
    SELECT get_website_id(data_source) INTO wdsid;
  ELSE
    RAISE EXCEPTION 'Unknown data source: %. Could not find in publication or website tables', data_source;
  END IF;

  SELECT EXISTS (
    SELECT true 
    FROM controlled_vocabulary_type 
    WHERE name = type
  ) INTO is_cv;

  IF NOT is_cv THEN
    SELECT EXISTS (
      SELECT true 
      FROM measurement 
      WHERE name = type
    ) INTO is_num;
  END IF;

  IF NOT is_cv AND NOT is_num THEN
    SELECT EXISTS (
      SELECT true 
      FROM tag_type
      WHERE name = type
    ) INTO is_tag;  
  END IF;

  IF is_cv THEN
    SELECT get_controlled_vocabulary_id(type, value) INTO vid;
    INSERT INTO controlled_vocabulary_property
      (pgdm_source_id, property_input_id, species_id, species_organ_id, 
      controlled_vocabulary_id, usda_zone_id, publication_id, website_id, accessed) 
    VALUES
      (pgdm_source_id, property_input_id, sid, soid, 
      vid, usda_zone, pdsid, wdsid, accessed);
  ELSIF is_num THEN
    SELECT get_measurement_id(type, unit) INTO vid;
    INSERT INTO measurement_property
      (pgdm_source_id, property_input_id, species_id, species_organ_id, 
      measurement_id, measurement_value, usda_zone_id, publication_id, website_id, accessed) 
    VALUES
      (pgdm_source_id, property_input_id, sid, soid, 
      vid, value::double precision, usda_zone, pdsid, wdsid, accessed);

  ELSIF is_tag THEN
    SELECT get_tag_type_id(type, value) INTO vid;
    INSERT INTO tag_property
      (pgdm_source_id, property_input_id, species_id, species_organ_id, 
      tag_type_id, tag_value, usda_zone_id, publication_id, website_id, accessed) 
    VALUES
      (pgdm_source_id, property_input_id, sid, soid, 
      vid, value, usda_zone, pdsid, wdsid, accessed);

  ELSE
    RAISE EXCEPTION 'Unknown type: %. The "type" column needs to be a known controlled vocabulary, measurement, or tag type', type;
  END IF;

END;
$$ LANGUAGE plpgsql;

-- Trigger function for insert
CREATE OR REPLACE FUNCTION properties_input_insert_trigger()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM insert_properties(
    property_input_id := NEW.property_input_id,
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    organ_name := NEW.organ_name,
    usda_zone := NEW.usda_zone,
    "values" := NEW.values,
    type := NEW.type,
    "precision" := NEW.precision,
    uncertainty := NEW.uncertainty,
    unit := NEW.unit,
    data_source := NEW.data_source,
    accessed := NEW.accessed,
    pgdm_source_name := NEW.source_name
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
    property_input_id := NEW.property_input_id,
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    organ_name := NEW.organ_name,
    usda_zone := NEW.usda_zone,
    "values" := NEW.values,
    type := NEW.type,
    "precision" := NEW.precision,
    uncertainty := NEW.uncertainty,
    unit := NEW.unit,
    data_source := NEW.data_source,
    accessed := NEW.accessed,
    pgdm_source_name := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- Create insert trigger
CREATE TRIGGER before_insert_properties_input
BEFORE INSERT ON properties_input
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
  IF (NEW.species_organ_id IS NOT NULL AND NEW.species_id IS NULL) THEN
    RAISE EXCEPTION 'If species_organ is specified, species must be specified';
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