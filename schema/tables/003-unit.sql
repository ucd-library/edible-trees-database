CREATE TABLE IF NOT EXISTS unit (
  unit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE
);

CREATE OR REPLACE FUNCTION get_unit_id(unit_name_in TEXT) RETURNS UUID AS $$
DECLARE
  uid UUID;
BEGIN
  SELECT unit_id INTO uid FROM unit WHERE name = unit_name_in;
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Unit % does not exist', unit_name_in;
  END IF;
  RETURN uid;
END;
$$ LANGUAGE plpgsql;