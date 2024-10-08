
CREATE TABLE IF NOT EXISTS organ (
  organ_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  name TEXT NOT NULL UNIQUE
);

CREATE OR REPLACE VIEW organ_view AS
  SELECT
    o.organ_id AS organ_id,
    o.name as name,
    sc.name AS source_name
  FROM
    organ o
  LEFT JOIN pgdm_source sc ON o.pgdm_source_id = sc.pgdm_source_id;

CREATE OR REPLACE FUNCTION insert_organ (
  organ_id UUID,
  name TEXT,
  source_name TEXT) RETURNS void AS $$
DECLARE
  pgdmid UUID;
BEGIN

  IF( organ_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO organ_id;
  END IF;
  SELECT get_source_id(source_name) INTO pgdmid;

  INSERT INTO organ (
    organ_id, name, pgdm_source_id
  ) VALUES (
    organ_id, name, pgdmid
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_organ (
  organ_id_in UUID,
  name_in TEXT) RETURNS void AS $$
DECLARE

BEGIN

  UPDATE organ SET (
    name 
  ) = (
    name_in
  ) WHERE
    organ_id = organ_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_organ_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_organ(
    organ_id := NEW.organ_id,
    name := NEW.name,
    source_name := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_organ_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM organ_genus(
    organ_id_in := NEW.organ_id,
    name_in := NEW.name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;


-- create a function to get the organ_id from the organ table
CREATE OR REPLACE FUNCTION get_organ_id(organ_name_in TEXT) RETURNS UUID AS $$
DECLARE
  oid UUID;
BEGIN
  SELECT organ_id INTO oid FROM organ WHERE name = organ_name_in;
  IF oid IS NULL THEN
    RAISE EXCEPTION 'Organ % does not exist', organ_name_in;
  END IF;
  RETURN oid;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER organ_insert_trig
  INSTEAD OF INSERT ON
  organ_view FOR EACH ROW 
  EXECUTE PROCEDURE insert_organ_from_trig();

CREATE TRIGGER organ_update_trig
  INSTEAD OF UPDATE ON
  organ_view FOR EACH ROW 
  EXECUTE PROCEDURE update_organ_from_trig();