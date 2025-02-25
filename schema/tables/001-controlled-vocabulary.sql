-- TABLES
CREATE TABLE IF NOT EXISTS controlled_vocabulary_type (
  controlled_vocabulary_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE
);
CREATE INDEX IF NOT EXISTS controlled_vocabulary_type_name_idx ON controlled_vocabulary_type(name);

-- Define controlled vocabulary types here
INSERT INTO controlled_vocabulary_type (name) VALUES ('bloom_period') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('fire_tolerance') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flower_anthers') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flower_color') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flower_direction') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flower_gender') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flower_nector') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flower_periodicity') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flower_petals') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flower_shape') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flower_size') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flower_symmetry') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flower_tube') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('flowering_duration') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('frost_tolerance') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('harvest_period') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('inflorescence_type') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('nectaries') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('nutrients') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('preparation') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('salinity_tolerance') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('shade_tolerance') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('soil_tolerance') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('leaf_retention') ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS controlled_vocabulary (
  controlled_vocabulary_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  controlled_vocabulary_type_id UUID REFERENCES controlled_vocabulary_type(controlled_vocabulary_type_id) NOT NULL,
  value TEXT NOT NULL,
  synonyms TEXT[],
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  UNIQUE(controlled_vocabulary_type_id, value)
);
CREATE INDEX IF NOT EXISTS controlled_vocabulary_source_id_idx ON controlled_vocabulary(pgdm_source_id);
CREATE INDEX IF NOT EXISTS controlled_vocabulary_value_idx ON controlled_vocabulary(value);
CREATE INDEX IF NOT EXISTS controlled_vocabulary_type_id_idx ON controlled_vocabulary(controlled_vocabulary_type_id);

-- VIEW
CREATE OR REPLACE VIEW controlled_vocabulary_view AS
  SELECT
    c.controlled_vocabulary_id AS controlled_vocabulary_id,
    ct.name as type,
    c.value as value,
    array_to_string(c.synonyms, ', ') as synonyms,
    sc.name AS source_name
  FROM
    controlled_vocabulary c
  LEFT JOIN controlled_vocabulary_type ct ON c.controlled_vocabulary_type_id = ct.controlled_vocabulary_type_id
  LEFT JOIN pgdm_source sc ON c.pgdm_source_id = sc.pgdm_source_id;

-- FUNCTION GETTERs
CREATE OR REPLACE FUNCTION get_controlled_vocabulary_type(type_in TEXT) RETURNS UUID AS $$
DECLARE
  ctid UUID;
BEGIN
    SELECT 
      controlled_vocabulary_type_id INTO ctid 
    FROM 
      controlled_vocabulary_type ct 
    WHERE  
      ct.name = type_in;
  
    IF (ctid IS NULL) THEN
      RAISE EXCEPTION 'Unknown controlled vocabulary type: %', type_in;
    END IF;
    
    RETURN ctid;
  END ;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_controlled_vocabulary_id(type_in TEXT, value_in TEXT) RETURNS UUID AS $$   
DECLARE
  cvid UUID;
  cvtid UUID;
BEGIN

  SELECT get_controlled_vocabulary_type(type_in) INTO cvtid;

  SELECT 
    controlled_vocabulary_id INTO cvid 
  FROM 
    controlled_vocabulary c 
  WHERE  
    c.controlled_vocabulary_type_id = cvtid AND
    c.value = value_in;

  IF (cvid IS NULL) THEN
    RAISE EXCEPTION 'Unknown controlled vocabulary: type=% value=%', type_in, value_in;
  END IF;
  
  RETURN cvid;
END ; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_cv_id_of_type(type_in TEXT, controlled_vocabulary_id_in UUID) RETURNS UUID AS $$
DECLARE
  v TEXT;
  cvtid UUID;
BEGIN
  
    SELECT get_controlled_vocabulary_type(type_in) INTO cvtid;
  
    SELECT 
      value INTO v 
    FROM 
      controlled_vocabulary c 
    WHERE  
      c.controlled_vocabulary_type_id = cvtid AND
      c.controlled_vocabulary_id = controlled_vocabulary_id_in;

    IF (v IS NULL) THEN
      SELECT value INTO v FROM controlled_vocabulary WHERE controlled_vocabulary_id = controlled_vocabulary_id_in;
      RAISE EXCEPTION 'Controlled vocabulary value=% is not of type=%', value, type_in;
    END IF;
    
    RETURN cvid;
  END ;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION split_and_trim(input_string TEXT)
RETURNS TEXT[] AS $$
BEGIN
    RETURN ARRAY(
        SELECT TRIM(value)
        FROM unnest(string_to_array(input_string, ',')) AS value
    );
END;
$$ LANGUAGE plpgsql;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION insert_controlled_vocabulary (
  controlled_vocabulary_id UUID,
  type TEXT,
  value TEXT,
  synonyms TEXT,
  source_name TEXT) RETURNS void AS $$   
DECLARE
  sid UUID;
  cvtid UUID;
  syn_arr TEXT[];
BEGIN

  SELECT get_controlled_vocabulary_type(type) INTO cvtid;

  IF( synonyms IS NOT NULL ) THEN
    syn_arr := split_and_trim(synonyms);
  END IF;

  IF( controlled_vocabulary_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO controlled_vocabulary_id;
  END IF;
  SELECT get_source_id(source_name) INTO sid;

  INSERT INTO controlled_vocabulary (
    controlled_vocabulary_id, controlled_vocabulary_type_id, value, synonyms, pgdm_source_id
  ) VALUES (
    controlled_vocabulary_id, cvtid, value, syn_arr, sid
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_controlled_vocabulary (
  controlled_vocabulary_id_in UUID,
  type_in UUID,
  synonyms_in TEXT,
  value_in TEXT) RETURNS void AS $$   
DECLARE
  cvtid UUID;
  syn_arr TEXT[];
BEGIN

  SELECT get_controlled_vocabulary_type(type_in) INTO cvtid;

  IF( synonyms_in IS NOT NULL ) THEN
    syn_arr := split_and_trim(synonyms_in);
  END IF;

  UPDATE controlled_vocabulary SET (
    type, value, synonyms
  ) = (
    type_in, value_in, syn_arr
  ) WHERE
    controlled_vocabulary_id = controlled_vocabulary_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION TRIGGERS
CREATE OR REPLACE FUNCTION insert_controlled_vocabulary_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_controlled_vocabulary(
    controlled_vocabulary_id := NEW.controlled_vocabulary_id,
    type := NEW.type,
    value := NEW.value,
    synonyms := NEW.synonyms,
    source_name := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_controlled_vocabulary_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM update_controlled_vocabulary(
    controlled_vocabulary_id_in := NEW.controlled_vocabulary_id,
    type_in := NEW.type,
    synonyms_in := NEW.synonyms,
    value_in := NEW.value
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- RULES
DO
$$BEGIN
  CREATE TRIGGER controlled_vocabulary_insert_trig
    INSTEAD OF INSERT ON
    controlled_vocabulary_view FOR EACH ROW 
    EXECUTE PROCEDURE insert_controlled_vocabulary_from_trig();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'The trigger controlled_vocabulary_insert_trig already exists.';
END$$;

DO
$$BEGIN
  CREATE TRIGGER controlled_vocabulary_update_trig
    INSTEAD OF UPDATE ON
    controlled_vocabulary_view FOR EACH ROW 
    EXECUTE PROCEDURE update_controlled_vocabulary_from_trig();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'The trigger controlled_vocabulary_update_trig already exists.';
END$$;