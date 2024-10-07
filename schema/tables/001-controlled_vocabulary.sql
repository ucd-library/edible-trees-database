-- TABLES
CREATE TABLE IF NOT EXISTS controlled_vocabulary_type (
  controlled_vocabulary_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
);
CREATE INDEX controlled_vocabulary_type_name_idx ON controlled_vocabulary_type(name);

-- Define controlled vocabulary types here
INSERT INTO controlled_vocabulary_type (name) VALUES ('shade_tolerance') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('fire_resilience') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('salinity_tolerance') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('soil_tolerance') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('unit') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('organ') ON CONFLICT DO NOTHIN
INSERT INTO controlled_vocabulary_type (name) VALUES ('species_preparation') ON CONFLICT DO NOTHING;
INSERT INTO controlled_vocabulary_type (name) VALUES ('species_toxicity') ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS controlled_vocabulary (
  controlled_vocabulary_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  controlled_vocabulary_type_id UUID REFERENCES controlled_vocabulary_type(controlled_vocabulary_type_id) NOT NULL,
  value TEXT NOT NULL,
  source_id UUID REFERENCES pgdm_source NOT NULL,
  UNIQUE(type_id, value)
);
CREATE INDEX controlled_vocabulary_source_id_idx ON controlled_vocabulary(source_id);
CREATE INDEX controlled_vocabulary_value_idx ON controlled_vocabulary(value);

-- VIEW
CREATE OR REPLACE VIEW controlled_vocabulary_view AS
  SELECT
    c.controlled_vocabulary_id AS controlled_vocabulary_id,
    ct.name as type,
    c.value as value,
    sc.name AS source_name
  FROM
    controlled_vocabulary c,
  LEFT JOIN controlled_vocabulary_type ct ON c.controlled_vocabulary_type_id = ct.controlled_vocabulary_type_id
  LEFT JOIN pgdm_source sc ON c.source_id = sc.source_id

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

-- FUNCTIONS
CREATE OR REPLACE FUNCTION insert_controlled_vocabulary (
  controlled_vocabulary_id UUID,
  type TEXT,
  value TEXT,
  source_name TEXT) RETURNS void AS $$   
DECLARE
  source_id UUID;
  cvtid UUID;
BEGIN

  SELECT get_controlled_vocabulary_type(type) INTO cvtid;

  IF( controlled_vocabulary_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO controlled_vocabulary_id;
  END IF;
  SELECT get_source_id(source_name) INTO source_id;

  INSERT INTO controlled_vocabulary (
    controlled_vocabulary_id, controlled_vocabulary_type_id, value, source_id
  ) VALUES (
    controlled_vocabulary_id, cvtid, value, source_id
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_controlled_vocabulary (
  controlled_vocabulary_id_in UUID,
  type_in UUID,
  value_in TEXT) RETURNS void AS $$   
DECLARE
  cvtid UUID;
BEGIN

  SELECT get_controlled_vocabulary_type(type_in) INTO cvtid;

  UPDATE controlled_vocabulary SET (
    type, value, 
  ) = (
    type_in, value_in
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
    value_in := NEW.value
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- RULES
CREATE TRIGGER controlled_vocabulary_insert_trig
  INSTEAD OF INSERT ON
  controlled_vocabulary_view FOR EACH ROW 
  EXECUTE PROCEDURE insert_controlled_vocabulary_from_trig();

CREATE TRIGGER controlled_vocabulary_update_trig
  INSTEAD OF UPDATE ON
  controlled_vocabulary_view FOR EACH ROW 
  EXECUTE PROCEDURE update_controlled_vocabulary_from_trig();