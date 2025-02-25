-- TABLE
CREATE TABLE IF NOT EXISTS tag_type (
  tag_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  name TEXT NOT NULL,
  description TEXT
);
CREATE INDEX IF NOT EXISTS tag_type_source_id_idx ON tag_type(pgdm_source_id);
CREATE INDEX IF NOT EXISTS tag_type_name_idx ON tag_type(name);

-- VIEW
CREATE OR REPLACE VIEW tag_type_view AS
  SELECT
    t.tag_type_id AS tag_type_id,
    t.name as name,
    t.description as description,
    sc.name AS source_name
  FROM
    tag_type t
LEFT JOIN pgdm_source sc ON t.pgdm_source_id = sc.pgdm_source_id;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION insert_tag_type (
  tag_type_id UUID,
  name TEXT,
  description TEXT,
  source_name TEXT) RETURNS void AS $$   
DECLARE
  pgdm_source_id UUID;
BEGIN

  IF( tag_type_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO tag_type_id;
  END IF;
  SELECT get_source_id(source_name) INTO pgdm_source_id;

  INSERT INTO tag_type (
    tag_type_id, name, description, pgdm_source_id
  ) VALUES (
    tag_type_id, name, description, pgdm_source_id
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_tag_type (
  tag_type_id_in UUID,
  name_in TEXT,
  description_in TEXT) RETURNS void AS $$   
DECLARE

BEGIN

  UPDATE tag_type SET (
    name, description 
  ) = (
    name_in, description_in
  ) WHERE
    tag_type_id = tag_type_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION TRIGGERS
CREATE OR REPLACE FUNCTION insert_tag_type_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_tag_type(
    tag_type_id := NEW.tag_type_id,
    name := NEW.name,
    description := NEW.description,
    pgdm_source_id := NEW.pgdm_source_id
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_tag_type_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM update_tag_type(
    tag_type_id_in := NEW.tag_type_id,
    name_in := NEW.name,
    description_in := NEW.description
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION GETTER
CREATE OR REPLACE FUNCTION get_tag_type_id(name_in TEXT) RETURNS UUID AS $$   
DECLARE
  tid UUID;
BEGIN

  SELECT 
    tag_type_id INTO tid 
  FROM 
    tag_type t 
  WHERE  
    t.name = name_in;

  IF (tid IS NULL) THEN
    RAISE EXCEPTION 'Unknown tag_type: %', name_in;
  END IF;
  
  RETURN tid;
END ; 
$$ LANGUAGE plpgsql;

-- RULES
DO
$$BEGIN
CREATE TRIGGER tag_type_insert_trig
  INSTEAD OF INSERT ON
  tag_type_view FOR EACH ROW 
  EXECUTE PROCEDURE insert_tag_type_from_trig();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'The trigger tag_type_insert_trig already exists.';
END$$;

DO
$$BEGIN
CREATE TRIGGER tag_type_update_trig
  INSTEAD OF UPDATE ON
  tag_type_view FOR EACH ROW 
  EXECUTE PROCEDURE update_tag_type_from_trig();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'The trigger tag_type_update_trig already exists.';
END$$;