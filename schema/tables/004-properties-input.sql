
CREATE TABLE IF NOT EXISTS properties_input (
  property_input_id UUID PRIMARY KEY,
  source_name TEXT REFERENCES pgdm_source(name) NOT NULL,
  genus_name TEXT NOT NULL,
  species_name TEXT NOT NULL,
  organ_name TEXT,
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
  "values" TEXT,
  type TEXT,
  "precision" FLOAT,
  uncertainty FLOAT,
  unit TEXT,
  data_source TEXT,
  accessed DATE
) RETURNS UUID AS $$
DECLARE
  sid UUID;
  value TEXT;
  is_update BOOLEAN;
BEGIN

  IF property_input_id IS NULL THEN
    SELECT uuid_generate_v4() INTO property_input_id;
    is_update := FALSE;
  ELSE
    is_update := TRUE;
  END IF;

  SELECT get_source_id(pgdm_source_name) INTO sid;

  FOR value IN SELECT unnest(string_to_array(values, ',')) AS value LOOP
    PERFORM insert_property(
      property_input_id_in := property_input_id,
      genus_name_in := genus_name,
      species_name_in := species_name,
      organ_name_in := organ_name,
      value_in := value,
      type_in := type,
      unit_in := unit,
      precision_in := precision,
      uncertainty_in := uncertainty,
      data_source_in := data_source,
      accessed_in := accessed,
      pgdm_source_id_in := sid,
      is_update_in := is_update
    );
  END LOOP;

  RETURN property_input_id;
EXCEPTION WHEN raise_exception THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION update_properties(
--   property_input_id_in UUID,
--   genus_name TEXT,
--   species_name TEXT,
--   organ_name TEXT,
--   usda_zone TEXT,
--   "values" TEXT,
--   type TEXT,
--   unit TEXT,
--   "precision" FLOAT,
--   uncertainty FLOAT,
--   data_source TEXT,
--   accessed DATE,
--   source_name TEXT
-- ) RETURNS VOID AS $$
-- BEGIN
--   PERFORM insert_properties(
--     property_input_id := property_input_id_in,
--     genus_name := genus_name,
--     species_name := species_name,
--     organ_name := organ_name,
--     usda_zone := usda_zone,
--     "values" := "values",
--     type := type,
--     "precision" := "precision",
--     uncertainty := uncertainty,
--     unit := unit,
--     data_source := data_source,
--     accessed := accessed,
--     pgdm_source_name := source_name
--   );
-- END;
-- $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION insert_property(
  property_input_id_in UUID,
  genus_name_in TEXT,
  species_name_in TEXT,
  organ_name_in TEXT,
  value_in TEXT,
  type_in TEXT,
  unit_in TEXT,
  precision_in FLOAT,
  uncertainty_in FLOAT,
  data_source_in TEXT,
  accessed_in DATE,
  pgdm_source_id_in UUID,
  is_update_in BOOLEAN
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
BEGIN
  SELECT get_species_id(genus_name_in, species_name_in) INTO sid;
  IF organ_name_in IS NOT NULL THEN
    SELECT get_species_organ_id(genus_name_in, species_name_in, organ_name_in) INTO soid;
  END IF;

  SELECT EXISTS (
    SELECT true 
    FROM publication p 
    WHERE p.doi = data_source_in 
  ) INTO is_pub;

  IF NOT is_pub THEN
    SELECT EXISTS (
      SELECT true 
      FROM website w
      WHERE w.url = data_source_in
    ) INTO is_web;
  END IF;

  IF is_pub THEN
    SELECT get_publication_id(data_source_in) INTO pdsid;
  ELSIF is_web THEN
    SELECT get_website_id(data_source_in) INTO wdsid;
  ELSE
    RAISE EXCEPTION 'Unknown data source: %. Could not find in publication or website tables', data_source_in;
  END IF;

  SELECT EXISTS (
    SELECT true 
    FROM controlled_vocabulary_type 
    WHERE name = type_in
  ) INTO is_cv;

  IF NOT is_cv THEN
    SELECT EXISTS (
      SELECT true 
      FROM measurement 
      WHERE name = type_in
    ) INTO is_num;
  END IF;

  IF NOT is_cv AND NOT is_num THEN
    SELECT EXISTS (
      SELECT true 
      FROM tag_type
      WHERE name = type_in
    ) INTO is_tag;  
  END IF;

  IF is_cv THEN
    SELECT get_controlled_vocabulary_id(type_in, value_in) INTO vid;

    IF is_update_in THEN
      UPDATE controlled_vocabulary_property AS cvp SET 
        pgdm_source_id = pgdm_source_id_in,
        species_id = sid,
        species_organ_id = soid,
        controlled_vocabulary_id = vid,
        publication_id = pdsid,
        website_id = wdsid,
        accessed = accessed_in
      WHERE cvp.property_input_id = property_input_id_in;

    ELSE
      INSERT INTO controlled_vocabulary_property
        (pgdm_source_id, property_input_id, species_id, species_organ_id, 
        controlled_vocabulary_id, publication_id, website_id, accessed) 
      VALUES
        (pgdm_source_id_in, property_input_id_in, sid, soid, 
        vid, pdsid, wdsid, accessed_in);
    END IF;


  ELSIF is_num THEN
    SELECT get_measurement_id(type_in, unit_in) INTO vid;

    IF is_update_in THEN

        UPDATE measurement_property AS mp SET 
          pgdm_source_id = pgdm_source_id_in,
          species_id = sid,
          species_organ_id = soid,
          measurement_id = vid,
          measurement_value = value_in::double precision,
          publication_id = pdsid,
          website_id = wdsid,
          accessed = accessed_in
        WHERE mp.property_input_id = property_input_id_in;

    ELSE

      INSERT INTO measurement_property
        (pgdm_source_id, property_input_id, species_id, species_organ_id, 
        measurement_id, measurement_value, publication_id, website_id, accessed) 
      VALUES
        (pgdm_source_id_in, property_input_id_in, sid, soid, 
        vid, value_in::double precision, pdsid, wdsid, accessed_in);

    END IF;

  ELSIF is_tag THEN
    SELECT get_tag_type_id(type_in, value_in) INTO vid;

    IF is_update_in THEN
      UPDATE tag_property AS tp SET 
        pgdm_source_id = pgdm_source_id_in,
        species_id = sid,
        species_organ_id = soid,
        tag_type_id = vid,
        tag_value = value_in,
        publication_id = pdsid,
        website_id = wdsid,
        accessed = accessed_in
      WHERE tp.sproperty_input_id = property_input_id_in;

    ELSE

      INSERT INTO tag_property
        (pgdm_source_id, property_input_id, species_id, species_organ_id, 
        tag_type_id, tag_value, publication_id, website_id, accessed) 
      VALUES
        (pgdm_source_id_in, property_input_id_in, sid, soid, 
        vid, value_in, pdsid, wdsid, accessed_in);
    END IF;

  ELSE
    RAISE EXCEPTION 'Unknown type: %. The "type" column needs to be a known controlled vocabulary, measurement, or tag type', type_in;
  END IF;

END;
$$ LANGUAGE plpgsql;

-- Trigger function for insert
CREATE OR REPLACE FUNCTION properties_input_insert_trigger()
RETURNS TRIGGER AS $$
DECLARE
  piid UUID;
BEGIN
  SELECT insert_properties(
    property_input_id := NEW.property_input_id,
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    organ_name := NEW.organ_name,
    "values" := NEW.values,
    type := NEW.type,
    "precision" := NEW.precision,
    uncertainty := NEW.uncertainty,
    unit := NEW.unit,
    data_source := NEW.data_source,
    accessed := NEW.accessed,
    pgdm_source_name := NEW.source_name
  ) INTO piid;

  IF piid IS NOT NULL THEN
    NEW.property_input_id := piid;
  END IF;

  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- Trigger function for update
CREATE OR REPLACE FUNCTION properties_input_update_trigger()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM insert_properties(
    property_input_id := NEW.property_input_id,
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    organ_name := NEW.organ_name,
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

CREATE OR REPLACE FUNCTION properties_input_delete_trigger()
RETURNS TRIGGER AS $$
BEGIN
  DELETE from controlled_vocabulary_property WHERE property_input_id = OLD.property_input_id;
  DELETE from measurement_property WHERE property_input_id = OLD.property_input_id;
  -- DELETE from tag_property WHERE property_input_id = OLD.property_input_id;
  RETURN OLD;
EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- Create insert trigger
DO
$$BEGIN
CREATE TRIGGER before_insert_properties_input
BEFORE INSERT ON properties_input
FOR EACH ROW
EXECUTE FUNCTION properties_input_insert_trigger();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'The trigger before_insert_properties_input already exists.';
END$$;

-- Create update trigger
DO
$$BEGIN
CREATE TRIGGER before_update_properties_input
BEFORE UPDATE ON properties_input
FOR EACH ROW
EXECUTE FUNCTION properties_input_update_trigger();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'The trigger before_update_properties_input already exists.';
END$$;

DO
$$BEGIN
CREATE TRIGGER after_delete_properties_input
BEFORE DELETE ON properties_input
FOR EACH ROW
EXECUTE FUNCTION properties_input_delete_trigger();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'The trigger after_delete_properties_input already exists.';
END$$;

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