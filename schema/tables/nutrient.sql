-- TABLE
DROP TABLE IF EXISTS nutrient CASCADE;
CREATE TABLE nutrient (
  nutrient_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_id UUID REFERENCES pgdm_source NOT NULL,
  name TEXT NOT NULL UNIQUE,
  unit_cv_id UUID REFERENCES controlled_vocabulary(controlled_vocabulary_id) NOT NULL,
  min_bound INTEGER,
  max_bound INTEGER
);
CREATE INDEX nutrient_source_id_idx ON nutrient(source_id);

-- VIEW
CREATE OR REPLACE VIEW nutrient_view AS
  SELECT
    n.nutrient_id AS nutrient_id,
    n.name as name,
    cv.value as unit,
    n.min_bound as min_bound,
    n.max_bound as max_bound,
    sc.name AS source_name
  FROM
    nutrient n
  LEFT JOIN controlled_vocabulary cv ON n.unit_id = cv.controlled_vocabulary_id,
  LEFT JOIN pgdm_source sc ON n.source_id = sc.source_id;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION insert_nutrient (
  nutrient_id UUID,
  name TEXT,
  unit TEXT,
  min_bound INTEGER,
  max_bound INTEGER,
  source_name TEXT) RETURNS void AS $$   
DECLARE
  source_id UUID;
  unit_cv_id UUID;
BEGIN

  SELECT get_controlled_vocabulary_id('unit', unit) INTO unit_cv_id;

  IF( nutrient_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO nutrient_id;
  END IF;
  SELECT get_source_id(source_name) INTO source_id;

  INSERT INTO nutrient (
    nutrient_id, name, unit_cv_id, min_bound, max_bound, source_id
  ) VALUES (
    nutrient_id, name, unit_cv_id, min_bound, max_bound, source_id
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_nutrient (
  nutrient_id_in UUID,
  name_in TEXT,
  unit_in TEXT,
  min_bound_in INTEGER,
  max_bound_in INTEGER) RETURNS void AS $$   
DECLARE
  unit_cv_id UUID;
BEGIN

  SELECT get_controlled_vocabulary_id('unit', unit_in) INTO unit_cv_id;

  UPDATE nutrient SET (
    name, unit_cv_id, min_bound, max_bound, 
  ) = (
    name_in, unit_cv_id, min_bound_in, max_bound_in
  ) WHERE
    nutrient_id = nutrient_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION TRIGGERS
CREATE OR REPLACE FUNCTION nutrient_update_checks()
RETURNS TRIGGER AS $$
BEGIN
    SELECT check_cv_id_of_type('unit', NEW.unit_cv_id);

    IF NEW.max_bound < NEW.min_bound THEN
      RAISE EXCEPTION 'Max bound must be greater than or equal to min bound';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_nutrient_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_nutrient(
    nutrient_id := NEW.nutrient_id,
    name := NEW.name,
    unit := NEW.unit,
    min_bound := NEW.min_bound,
    max_bound := NEW.max_bound,
    source_name := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_nutrient_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM update_nutrient(
    nutrient_id_in := NEW.nutrient_id,
    name_in := NEW.name,
    unit_in := NEW.unit,
    min_bound_in := NEW.min_bound,
    max_bound_in := NEW.max_bound
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION GETTER
CREATE OR REPLACE FUNCTION get_nutrient_id(name TEXT) RETURNS UUID AS $$   
DECLARE
  nid UUID;
BEGIN

  SELECT 
    nutrient_id INTO nid 
  FROM 
    nutrient n 
  WHERE  
    n.name = name;

  IF (nid IS NULL) THEN
    RAISE EXCEPTION 'Unknown nutrient: %', name;
  END IF;
  
  RETURN nid;
END ; 
$$ LANGUAGE plpgsql;

-- TRIGGERS
CREATE TRIGGER nutrient_update_checks_trigger
  BEFORE INSERT OR UPDATE ON nutrient
  FOR EACH ROW EXECUTE FUNCTION nutrient_update_checks();

CREATE TRIGGER nutrient_insert_trig
  INSTEAD OF INSERT ON
  nutrient_view FOR EACH ROW 
  EXECUTE PROCEDURE insert_nutrient_from_trig();

CREATE TRIGGER nutrient_update_trig
  INSTEAD OF UPDATE ON
  nutrient_view FOR EACH ROW 
  EXECUTE PROCEDURE update_nutrient_from_trig();