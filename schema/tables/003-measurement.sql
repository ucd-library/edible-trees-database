-- TABLE
CREATE TABLE IF NOT EXISTS measurement (
  measurement_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  name TEXT NOT NULL,
  unit_id UUID REFERENCES unit NOT NULL
);
CREATE INDEX IF NOT EXISTS measurement_source_id_idx ON measurement(pgdm_source_id);

-- VIEW
CREATE OR REPLACE VIEW measurement_view AS
  SELECT
    m.measurement_id AS measurement_id,
    m.name as name,
    u.name as unit,
    sc.name AS source_name
  FROM
    measurement m
  LEFT JOIN unit u ON m.unit_id = u.unit_id
  LEFT JOIN pgdm_source sc ON m.pgdm_source_id = sc.pgdm_source_id;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION insert_measurement (
  measurement_id UUID,
  name TEXT,
  unit TEXT,
  source_name TEXT) RETURNS void AS $$   
DECLARE
  sid UUID;
  uid UUID;
BEGIN

  IF( measurement_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO measurement_id;
  END IF;
  SELECT get_source_id(source_name) INTO sid;
  SELECT get_unit_id(unit) INTO uid;

  INSERT INTO measurement (
    measurement_id, name, unit_id, pgdm_source_id
  ) VALUES (
    measurement_id, name, uid, sid
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_measurement (
  measurement_id_in UUID,
  name_in TEXT,
  unit_in TEXT) RETURNS void AS $$   
DECLARE
  uid UUID;
BEGIN

  SELECT get_unit_id(unit_in) INTO uid;

  UPDATE measurement SET (
    name, unit_id
  ) = (
    name_in, unit_id
  ) WHERE
    measurement_id = measurement_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION TRIGGERS
CREATE OR REPLACE FUNCTION insert_measurement_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_measurement(
    measurement_id := NEW.measurement_id,
    name := NEW.name,
    unit := NEW.unit,
    source_name := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_measurement_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM update_measurement(
    measurement_id_in := NEW.measurement_id,
    name_in := NEW.name,
    unit_in := NEW.unit
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION GETTER
CREATE OR REPLACE FUNCTION get_measurement_id(name_in text, unit_in text) RETURNS UUID AS $$   
DECLARE
  mid UUID;
  uid UUID;
BEGIN

  select get_unit_id(unit_in) INTO uid;

  SELECT 
    measurement_id INTO mid 
  FROM 
    measurement m 
  WHERE
    m.name = name_in AND 
    m.unit_id = uid;

  IF (mid IS NULL) THEN
    RAISE EXCEPTION 'Unknown measurement: name=% unit=%', name_in, unit_in;
  END IF;
  
  RETURN mid;
END ; 
$$ LANGUAGE plpgsql;

-- RULES
DO
$$BEGIN
CREATE TRIGGER measurement_insert_trig
  INSTEAD OF INSERT ON
  measurement_view FOR EACH ROW 
  EXECUTE PROCEDURE insert_measurement_from_trig();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'The trigger measurement_insert_trig already exists.';
END$$;

DO
$$BEGIN
CREATE TRIGGER measurement_update_trig
  INSTEAD OF UPDATE ON
  measurement_view FOR EACH ROW 
  EXECUTE PROCEDURE update_measurement_from_trig();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'The trigger measurement_update_trig already exists.';
END$$;