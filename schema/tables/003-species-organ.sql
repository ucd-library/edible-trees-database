-- a relationship table between common_name and organ
CREATE TABLE IF NOT EXISTS species_organ (
  species_organ_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  species_id UUID NOT NULL REFERENCES species(species_id),
  organ_id UUID NOT NULL REFERENCES organ(organ_id)
);
CREATE INDEX species_species_organ_id_idx ON species_organ(species_id);
CREATE INDEX species_organ_organ_id_idx ON species_organ(organ_id);

-- join the species, genus, common_name, and organ tables for the 
-- full species organ view with text names
CREATE OR REPLACE VIEW species_organ_view AS
  SELECT
    so.species_organ_id AS species_organ_id,
    g.name AS genus_name,
    g.genus_id AS genus_id,
    s.name AS species_name,
    s.species_id AS species_id,
    o.name AS organ_name,
    o.organ_id AS organ_id,
    sc.name AS source_name
  FROM species_organ so
  LEFT JOIN species s ON so.species_id = s.species_id
  LEFT JOIN genus g ON s.genus_id = g.genus_id
  LEFT JOIN organ o ON so.organ_id = o.organ_id
  LEFT JOIN pgdm_source sc ON sc.pgdm_source_id = s.pgdm_source_id;

CREATE FUNCTION get_species_organ_id(
  genius_name TEXT,
  species_name TEXT,
  organ_name TEXT
) RETURNS UUID AS $$
DECLARE
  sid UUID;
  oid UUID;
  soid UUID;
BEGIN

  SELECT get_species_id(genus_name, species_name) INTO sid;
  SELECT get_organ_id(organ_name, organ_name) INTO oid;

  SELECT species_organ_id INTO soid FROM species_organ
  WHERE species_id = gid AND organ_id = oid;

  IF soid IS NULL THEN
    RAISE EXCEPTION 'Species Organ genus=%, species=%, organ=% does not exist', genus_name, species_name, organ_name;
  END IF;

  RETURN sid;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION insert_species_organ(
  species_organ_id UUID,
  genus_name TEXT,
  species_name TEXT,
  organ_name TEXT,
  source_name TEXT
) RETURNS UUID AS $$
DECLARE
  sid UUID;
  oid UUID;
  gid UUID;
BEGIN
  
    SELECT get_species_id(genus_name, species_name) INTO gid;
    SELECT get_organ_id(organ_name) INTO oid;
    SELECT get_source_id(source_name) INTO sid;

    IF( species_organ_id IS NULL ) THEN
      SELECT uuid_generate_v4() INTO species_organ_id;
    END IF;

    INSERT INTO species_organ (
      species_organ_id, species_id, organ_id, pgdm_source_id
    ) VALUES (
      species_organ_id, gid, oid, sid
    );

    RETURN species_organ_id;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_species_organ(
  species_organ_id_in UUID,
  genus_name TEXT,
  species_name TEXT,
  organ_name TEXT
) RETURNS VOID AS $$
DECLARE
  sid UUID;
  oid UUID;
  gid UUID;
BEGIN
  
    SELECT get_species_id(genus_name, species_name) INTO gid;
    SELECT get_organ_id(organ_name) INTO oid;
  
    UPDATE species_organ SET (
      species_id, organ_id
    ) = (
      gid, oid
    ) WHERE
      species_organ_id = species_organ_id_in;
  
    EXCEPTION WHEN raise_exception THEN
      RAISE;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_species_organ_from_trig()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM insert_species_organ(
    species_organ_id := NEW.species_organ_id,
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    organ_name := NEW.organ_name,
    source_name := NEW.source_name
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_species_organ_from_trig()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM update_species_organ(
    species_organ_id_in := NEW.species_organ_id,
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    organ_name := NEW.organ_name
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- TRIGGERS
CREATE TRIGGER insert_species_organ_trig
INSTEAD OF INSERT ON species_organ_view
FOR EACH ROW EXECUTE FUNCTION insert_species_organ_from_trig();

CREATE TRIGGER update_species_organ_trig
INSTEAD OF UPDATE ON species_organ_view
FOR EACH ROW EXECUTE FUNCTION update_species_organ_from_trig();
