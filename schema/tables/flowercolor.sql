-- first attempt at coding for this project
-- still have no idea how to commit this...

-- create the table
CREATE TABLE IF NOT EXISTS flower_color (
  flowercolor_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE
);

-- create function to get colors from flowercolor_table
CREATE OR REPLACE FUNCTION get_flower_color(color_name_in TEXT) RETURNS UUID AS $$
DECLARE
  oid UUID;
BEGIN
  SELECT flowercolor_id_id INTO oid FROM color WHERE name = color_name_in;
  IF oid IS NULL THEN
    RAISE EXCEPTION 'Color % does not exist', color_name_in;
  END IF;
  RETURN oid;
END;
$$ LANGUAGE plpgsql;

-- create a view for colors of flower and species (pretty niche use case, but why not)
oin the species, genus, common_name, and organ tables for the 
-- full species organ view with text names
CREATE OR REPLACE VIEW flowercolor_view AS
  SELECT
    s.name AS species_name,
    s.species_id AS species_id,
    cn.name AS common_name_name,
    cn.common_name_id AS common_name_id,
  FROM species s 
  JOIN common_name cn ON cn.species_id = s.species_id
  JOIN flower_color fc ON so.flowercolor_id = o.flowercolor_id;
