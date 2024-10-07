 set search_path=edible_trees;

-- TABLE
CREATE TABLE IF NOT EXISTS usda_zone (
  usda_zone_id TEXT PRIMARY KEY,
  min_temp_min FLOAT,
  min_temp_max FLOAT,
  source_id UUID REFERENCES pgdm_source NOT NULL
);
CREATE INDEX usda_zone_source_id_idx ON usda_zone(source_id);

-- VIEW
CREATE OR REPLACE VIEW usda_zone_view AS
  SELECT
    u.usda_zone_id AS usda_zone_id,
    sc.name AS source_name
  FROM
    usda_zone u
LEFT JOIN pgdm_source sc ON u.source_id = sc.source_id;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION insert_usda_zone (
  usda_zone_id TEXT,
  source_name TEXT) RETURNS void AS $$   
DECLARE
  source_id UUID;
BEGIN

  SELECT get_source_id(source_name) INTO source_id;

  INSERT INTO usda_zone (
    usda_zone_id, source_id
  ) VALUES (
    usda_zone_id, source_id
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION TRIGGERS
CREATE OR REPLACE FUNCTION insert_usda_zone_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_usda_zone(
    usda_zone_id := NEW.usda_zone_id,
    source_name := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- RULES
CREATE TRIGGER usda_zone_insert_trig
  INSTEAD OF INSERT ON
  usda_zone_view FOR EACH ROW 
  EXECUTE PROCEDURE insert_usda_zone_from_trig();
