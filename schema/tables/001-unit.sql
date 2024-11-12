-- TABLE
DROP TABLE IF EXISTS unit CASCADE;
CREATE TABLE unit (
  unit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  name TEXT NOT NULL UNIQUE
);
CREATE INDEX unit_source_id_idx ON unit(pgdm_source_id);

-- VIEW
CREATE OR REPLACE VIEW unit_view AS
  SELECT
    u.unit_id AS unit_id,
    u.name  as name,
    sc.name AS source_name
  FROM
    unit u
LEFT JOIN pgdm_source sc ON u.pgdm_source_id = sc.pgdm_source_id;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION insert_unit (
  unit_id UUID,
  name TEXT,
  source_name TEXT) RETURNS void AS $$   
DECLARE
  pgdm_source_id UUID;
BEGIN

  IF( unit_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO unit_id;
  END IF;
  SELECT get_source_id(source_name) INTO pgdm_source_id;

  INSERT INTO unit (
    unit_id, name, pgdm_source_id
  ) VALUES (
    unit_id, name, pgdm_source_id
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_unit (
  unit_id_in UUID,
  name_in TEXT) RETURNS void AS $$   
DECLARE

BEGIN

  UPDATE unit SET (
    name 
  ) = (
    name_in
  ) WHERE
    unit_id = unit_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION TRIGGERS
CREATE OR REPLACE FUNCTION insert_unit_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_unit(
    unit_id := NEW.unit_id,
    name := NEW.name,
    source_name := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_unit_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM update_unit(
    unit_id_in := NEW.unit_id,
    name_in := NEW.name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION GETTER
CREATE OR REPLACE FUNCTION get_unit_id(name_in text) RETURNS UUID AS $$   
DECLARE
  uid UUID;
BEGIN

  SELECT 
    unit_id INTO uid 
  FROM 
    unit u 
  WHERE  
    u.name = name_in;

  IF (uid IS NULL) THEN
    RAISE EXCEPTION 'Unknown unit: %', name_in;
  END IF;
  
  RETURN uid;
END ; 
$$ LANGUAGE plpgsql;

-- RULES
CREATE TRIGGER unit_insert_trig
  INSTEAD OF INSERT ON
  unit_view FOR EACH ROW 
  EXECUTE PROCEDURE insert_unit_from_trig();

CREATE TRIGGER unit_update_trig
  INSTEAD OF UPDATE ON
  unit_view FOR EACH ROW 
  EXECUTE PROCEDURE update_unit_from_trig();