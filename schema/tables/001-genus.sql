-- TABLE
CREATE TABLE IF NOT EXISTS genus (
  genus_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  name TEXT NOT NULL UNIQUE
);
CREATE INDEX IF NOT EXISTS genus_pgdm_source_id_idx ON genus(pgdm_source_id);
CREATE INDEX IF NOT EXISTS genus_name_idx ON genus(name);

-- VIEW
CREATE OR REPLACE VIEW genus_view AS
  SELECT
    g.genus_id AS genus_id,
    g.name as name,
    sc.name AS source_name
  FROM
    genus g
LEFT JOIN pgdm_source sc ON g.pgdm_source_id = sc.pgdm_source_id;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION insert_genus (
  genus_id UUID,
  name TEXT,
  source_name TEXT) RETURNS void AS $$   
DECLARE
  pgdm_source_id UUID;
BEGIN

  IF( genus_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO genus_id;
  END IF;
  SELECT get_source_id(source_name) INTO pgdm_source_id;

  INSERT INTO genus (
    genus_id, name, pgdm_source_id
  ) VALUES (
    genus_id, name, pgdm_source_id
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_genus (
  genus_id_in UUID,
  name_in TEXT) RETURNS void AS $$   
DECLARE

BEGIN

  UPDATE genus SET (
    name 
  ) = (
    name_in
  ) WHERE
    genus_id = genus_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION TRIGGERS
CREATE OR REPLACE FUNCTION insert_genus_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_genus(
    genus_id := NEW.genus_id,
    name := NEW.name,
    source_name := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_genus_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM update_genus(
    genus_id_in := NEW.genus_id,
    name_in := NEW.name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION GETTER
CREATE OR REPLACE FUNCTION get_genus_id(genus_name TEXT) RETURNS UUID AS $$   
DECLARE
  gid UUID;
BEGIN

  SELECT 
    genus_id INTO gid 
  FROM 
    genus g 
  WHERE  
    g.name = genus_name;

  IF (gid IS NULL) THEN
    RAISE EXCEPTION 'Unknown genus: %', genus_name;
  END IF;
  
  RETURN gid;
END ; 
$$ LANGUAGE plpgsql;

-- TRIGGERS
DO
$$BEGIN
  CREATE TRIGGER genus_insert_trig
    INSTEAD OF INSERT ON
    genus_view FOR EACH ROW 
    EXECUTE PROCEDURE insert_genus_from_trig();
EXCEPTION
  WHEN duplicate_object THEN
    -- Handle the exception here
    RAISE NOTICE 'The trigger genus_insert_trig already exists.';
END$$;

DO
$$BEGIN
  CREATE TRIGGER genus_update_trig
    INSTEAD OF UPDATE ON
    genus_view FOR EACH ROW 
    EXECUTE PROCEDURE update_genus_from_trig();
EXCEPTION
  WHEN duplicate_object THEN
    -- Handle the exception here
    RAISE NOTICE 'The trigger genus_insert_trig already exists.';
END$$;