CREATE TABLE IF NOT EXISTS species (
  species_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  genus_id UUID NOT NULL REFERENCES genus(genus_id),
  name TEXT NOT NULL,
  UNIQUE (genus_id, name)
);

-- join the species, genus, tables for the full species name view
CREATE OR REPLACE VIEW species_view AS
  SELECT
    s.species_id AS species_id,
    g.name AS genus_name,
    s.name AS species_name,
    ps.name AS source_name
  FROM species s
  LEFT JOIN pgdm_source ps ON ps.pgdm_source_id = s.pgdm_source_id
  LEFT JOIN genus g ON s.genus_id = g.genus_id;

-- create a function to get the species_id from the species_view
-- given the genus_name, species_name
CREATE OR REPLACE FUNCTION get_species_id(genus_name_in TEXT, species_name_in TEXT)
RETURNS UUID AS $$
DECLARE
  gid UUID;
  sid UUID;
BEGIN

  SELECT get_genus_id(genus_name_in) INTO gid;

  SELECT species_id INTO sid FROM species 
  WHERE 
    genus_id = gid AND 
    species_name = species_name_in;
  
  IF sid IS NULL THEN
    RAISE EXCEPTION 'Species genus=%, species=% does not exist', genus_name_in, species_name_in;
  END IF;

  RETURN sid;
END;
$$ LANGUAGE plpgsql;

-- create a function to ensure that a species exists in the database
CREATE OR REPLACE FUNCTION insert_species(
  species_id UUID,
  genus_name TEXT,
  species_name TEXT,
  source_name TEXT
) RETURNS VOID AS $$
DECLARE
  gid UUID;
  cnid UUID;
  source_id UUID;
BEGIN
  SELECT get_source_id(source_name) INTO source_id;
  SELECT get_genus_id(genus_name) INTO gid;

  -- new insert
  IF( species_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO species_id;
  END IF;
  
  INSERT INTO species 
    (species_id, genus_id, pgdm_source_id, name) 
  VALUES 
    (species_id, gid, source_id, species_name);

EXCEPTION WHEN raise_exception THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_species (
  genus_name_in TEXT,
  species_id_in UUID,
  species_name_in TEXT
) RETURNS VOID AS $$
DECLARE
  gid UUID;
BEGIN
  
  SELECT get_genus_id(genus_name_in) INTO gid;

  UPDATE species SET 
    genus_id = gid,
    name = species_name_in
  WHERE 
    species_id = species_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_species_from_trig()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM insert_species(
    species_id := NEW.species_id,
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    source_name := NEW.source_name
  );
  RETURN NEW;
EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_species_from_trig()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM update_species(
    species_id_in := NEW.species_id,
    genus_name_in := NEW.genus_name,
    species_name_in := NEW.species_name
  );
  RETURN NEW;
EXCEPTION WHEN raise_exception THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

-- TRIGGERS
DO
$$BEGIN
  CREATE TRIGGER species_insert_trig
    INSTEAD OF INSERT ON
    species_view FOR EACH ROW 
    EXECUTE PROCEDURE insert_species_from_trig();
EXCEPTION
  WHEN duplicate_object THEN
    -- Handle the exception here
    RAISE NOTICE 'The trigger species_insert_trig already exists.';
END$$;

DO
$$BEGIN
  CREATE TRIGGER species_update_trig
    INSTEAD OF UPDATE ON
    species_view FOR EACH ROW 
    EXECUTE PROCEDURE update_species_from_trig();
EXCEPTION
  WHEN duplicate_object THEN
    -- Handle the exception here
    RAISE NOTICE 'The trigger species_insert_trig already exists.';
END$$;