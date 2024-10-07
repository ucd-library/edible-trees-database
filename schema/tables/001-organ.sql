
CREATE TABLE IF NOT EXISTS organ (
  organ_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE
);

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
  FROM species s 
  JOIN common_name cn ON cn.species_id = s.species_id
  JOIN genus g ON s.genus_id = g.genus_id
  JOIN species_organ so ON s.species_id = so.species_id
  JOIN organ o ON so.organ_id = o.organ_id;

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

-- create a function to add a species/organ relationship
CREATE OR REPLACE FUNCTION add_species_organ(
  genus_name_in TEXT, 
  species_name_in TEXT,  
  organ_name_in TEXT) 
RETURNS VOID AS $$
DECLARE
  sid UUID;
  oid UUID;
BEGIN
  SELECT get_species_id(genus_name_in, species_name_in) INTO sid;
  SELECT organ_id INTO oid FROM organ WHERE name = organ_name_in;
  INSERT INTO species_organ (common_name_id, organ_id) VALUES (sid, oid);
END;
$$ LANGUAGE plpgsql;