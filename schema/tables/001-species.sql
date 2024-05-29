CREATE TABLE IF NOT EXISTS genus (
  genus_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  source UUID NOT NULL REFERENCES source(source_id) 
);

CREATE TABLE IF NOT EXISTS species (
  species_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  genus_id UUID NOT NULL REFERENCES genus(genus_id),
  name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS common_name (
  common_name_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  species_id UUID NOT NULL REFERENCES species(species_id),
  name TEXT NOT NULL UNIQUE
);

-- join the species, genus, and common_name tables for the full species name view
CREATE OR REPLACE VIEW species_view AS
  SELECT
    g.name AS genus_name,
    g.genus_id AS genus_id,
    s.name AS species_name,
    s.species_id AS species_id,
    cn.name AS common_name,
    cn.common_name_id AS common_name_id
  FROM common_name cn
  LEFT JOIN species s ON cn.species_id = s.species_id
  LEFT JOIN genus g ON s.genus_id = g.genus_id;

-- create a function to get the species_id from the species_view
-- given the genus_name, species_name
CREATE OR REPLACE FUNCTION get_species_id(genus_name_in TEXT, species_name_in TEXT)
RETURNS UUID AS $$
DECLARE
  sid UUID;
BEGIN
  SELECT 
    species_id INTO sid 
  FROM species_view 
  WHERE 
    genus_name = genus_name_in AND 
    species_name = species_name_in
  LIMIT 1;
  
  IF sid IS NULL THEN
    RAISE EXCEPTION 'Species genus=%, species=% does not exist', genus_name_in, species_name_in;
  END IF;

  RETURN sid;
END;
$$ LANGUAGE plpgsql;

-- create a function to ensure that a species exists in the database
CREATE OR REPLACE FUNCTION ensure_species_exists(
  genus_name TEXT,
  species_name TEXT,
  common_name TEXT
) RETURNS VOID AS $$
DECLARE
  gid UUID;
  sid UUID;
  cnid UUID;
BEGIN
  SELECT genus_id INTO gid FROM genus WHERE name = genus_name;
  IF gid IS NULL THEN
    INSERT INTO genus (name) VALUES (genus_name) RETURNING genus_id INTO gid;
  END IF;

  SELECT species_id INTO sid FROM species WHERE genus_id = gid AND name = species_name;
  IF sid IS NULL THEN
    INSERT INTO species (genus_id, name) VALUES (gid, species_name) RETURNING species_id INTO sid;
  END IF;

  SELECT common_name_id INTO cnid FROM common_name WHERE sid = species_id AND name = common_name;
  IF cnid IS NULL THEN
    INSERT INTO common_name (species_id, name) VALUES (sid, common_name);
  END IF;
END;
$$ LANGUAGE plpgsql;