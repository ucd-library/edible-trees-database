-- a relationship table between common_name and organ
CREATE TABLE IF NOT EXISTS species_organ (
  species_organ_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  species_id UUID NOT NULL REFERENCES species(species_id),
  organ_id UUID NOT NULL REFERENCES organ(organ_id)
);

-- join the species, genus, common_name, and organ tables for the 
-- full species organ view with text names
CREATE OR REPLACE VIEW species_organ_view AS
  SELECT
    g.name AS genus_name,
    g.genus_id AS genus_id,
    s.name AS species_name,
    s.species_id AS species_id,
    cn.name AS common_name_name,
    cn.common_name_id AS common_name_id,
    o.name AS organ_name,
    o.organ_id AS organ_id
    sc.name AS source_name
  FROM species_organ so
  LEFT JOIN species s ON so.species_id = s.species_id
  LEFT JOIN common_name cn ON cn.species_id = s.species_id
  LEFT JOIN genus g ON s.genus_id = g.genus_id
  LEFT JOIN species_organ so ON s.species_id = so.species_id
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
  SELECT get_organ_id(organ_name) INTO oid;

  SELECT species_organ_id INTO soid FROM species_organ
  WHERE species_id = gid AND organ_id = oid;

  IF soid IS NULL THEN
    RAISE EXCEPTION 'Species Organ genus=%, species=%, organ=% does not exist', genus_name, species_name, organ_name;
  END IF;

  RETURN sid;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION insert_species_organ(
  organ_species_id_in UUID,
  genus_name_in TEXT,
  species_name_in TEXT,
  organ_name_in TEXT,
  source_name_in TEXT
) RETURNS UUID AS $$
DECLARE
  sid UUID;
  oid UUID;
  gid UUID;
BEGIN
  
    SELECT get_species_id(genus_name_in, species_name_in) INTO gid;
    SELECT get_organ_id(organ_name_in) INTO oid;
    SELECT get_source_id(source_name_in) INTO sid;

    IF( organ_species_id_in IS NULL ) THEN
      SELECT uuid_generate_v4() INTO organ_species_id_in;
    END IF;

    INSERT INTO species_organ (
      species_organ_id, species_id, organ_id, pgdm_source_id
    ) VALUES (
      organ_species_id_in, gid, oid, sid
    );

    RETURN organ_species_id_in;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION update_species_organ(
  organ_species_id_in UUID,
  genus_name_in TEXT,
  species_name_in TEXT,
  organ_name_in TEXT
) RETURNS VOID AS $$
DECLARE
  sid UUID;
  oid UUID;
  gid UUID;
BEGIN
  
    SELECT get_species_id(genus_name_in, species_name_in) INTO gid;
    SELECT get_organ_id(organ_name_in) INTO oid;
  
    UPDATE species_organ SET (
      species_id, organ_id
    ) = (
      gid, oid
    ) WHERE
      species_organ_id = organ_species_id_in;
  
    EXCEPTION WHEN raise_exception THEN
      RAISE;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION insert_species_organ_from_trig()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM insert_species_organ(
    organ_species_id := NEW.organ_species_id,
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    organ_name := NEW.organ_name,
    source_name := NEW.source_name
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION update_species_organ_from_trig()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM update_species_organ(
    organ_species_id := NEW.organ_species_id,
    genus_name := NEW.genus_name,
    species_name := NEW.species_name,
    organ_name := NEW.organ_name
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- TRIGGERS
CREATE TRIGGER insert_species_organ_trig
AFTER INSERT ON species_organ
FOR EACH ROW EXECUTE FUNCTION insert_species_organ_from_trig();

CREATE TRIGGER update_species_organ_trig
AFTER UPDATE ON species_organ
FOR EACH ROW EXECUTE FUNCTION update_species_organ_from_trig();
