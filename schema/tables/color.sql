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
