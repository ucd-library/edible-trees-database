-- TABLE
DROP TABLE IF EXISTS organ_part CASCADE;
CREATE TABLE organ_part (
  organ_part_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_id UUID REFERENCES pgdm_source NOT NULL,
  organ_id UUID REFERENCES organ NOT NULL,
  name TEXT NOT NULL
);
CREATE INDEX organ_part_source_id_idx ON organ_part(source_id);

-- VIEW
CREATE OR REPLACE VIEW organ_part_view AS
  SELECT
    op.organ_part_id AS organ_part_id,
    op.name as part_name,
    o.name as organ_name,
    sc.name AS source_name
  FROM
    organ_part op
LEFT JOIN organ o ON o.organ_id = o.organ_id
LEFT JOIN pgdm_source sc ON o.source_id = sc.source_id;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION insert_organ_part (
  organ_part_id UUID,
  part_name TEXT,
  organ_name TEXT,
  source_name TEXT) RETURNS void AS $$   
DECLARE
  source_id UUID;
  oid UUID;
BEGIN

  IF( organ_part_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO organ_part_id;
  END IF;
  SELECT get_source_id(source_name) INTO source_id;
  SELECT get_organ_id(organ_name) INTO oid;

  INSERT INTO organ_part (
    organ_part_id, part_name, organ_id, source_id
  ) VALUES (
    organ_part_id, part_name, oid, source_id
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_organ_part (
  organ_part_id_in UUID,
  part_name_in TEXT,
  organ_name_in TEXT) RETURNS void AS $$   
DECLARE
  oid UUID;
BEGIN
  SELECT get_organ_id(organ_name_in) INTO oid;

  UPDATE organ_part SET (
    part_name, organ_id, 
  ) = (
    part_name_in, oid
  ) WHERE
    organ_part_id = organ_part_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION TRIGGERS
CREATE OR REPLACE FUNCTION insert_organ_part_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_organ_part(
    organ_part_id := NEW.organ_part_id,
    part_name := NEW.part_name,
    organ_name := NEW.organ_name,
    source_name := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_organ_part_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM update_organ_part(
    organ_part_id_in := NEW.organ_part_id,
    part_name_in := NEW.part_name,
    organ_name_in := NEW.organ_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION GETTER
CREATE OR REPLACE FUNCTION get_organ_part_id(organ_name TEXT, part_name TEXT) RETURNS UUID AS $$   
DECLARE

BEGIN

  SELECT 
    organ_part_id INTO oid 
  FROM 
    organ_part o 
  WHERE 
    o.name = part_name AND 
    o.organ_id = get_organ_id(organ_name);

  IF (oid IS NULL) THEN
    RAISE EXCEPTION 'Unknown organ_part: organ="%" part="%" ', organ_name, part_name;
  END IF;
  
  RETURN oid;
END ; 
$$ LANGUAGE plpgsql;

-- RULES
CREATE TRIGGER organ_part_insert_trig
  INSTEAD OF INSERT ON
  organ_part_view FOR EACH ROW 
  EXECUTE PROCEDURE insert_organ_part_from_trig();

CREATE TRIGGER organ_part_update_trig
  INSTEAD OF UPDATE ON
  organ_part_view FOR EACH ROW 
  EXECUTE PROCEDURE update_organ_part_from_trig();