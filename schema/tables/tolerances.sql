-- have not added the USDA zones yet, i want to fully understand the structure  before adding it
-- relationship table between species and all tolerances

-- JM: which columns be NOT NULL?
CREATE TABLE IF NOT EXISTS tolerance (
  tolerance_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  species_id UUID NOT NULL REFERENCES species(species_id) NOT NULL UNIQUE,
  fire_cv_id UUID  REFERENCES controlled_vocabulary(controlled_vocabulary_id),
  salinity_cv_id UUID  REFERENCES controlled_vocabulary(controlled_vocabulary_id),
  shade_cv_id UUID  REFERENCES controlled_vocabulary(controlled_vocabulary_id),
  soil_cv_id UUID  REFERENCES controlled_vocabulary(controlled_vocabulary_id),
  precipitation_max INTEGER,
  precipitation_min INTEGER,
  frost_min INTEGER,
  frost_max INTEGER
);

-- VIEW
CREATE OR REPLACE VIEW tolerance_view (
  SELECT
    t.tolerance_id AS tolerance_id,
    g.name AS genus_name,
    s.name AS species_name,
    f.value AS fire,
    st.value AS salinity,
    sh.value AS shade,
    so.value AS soil,
    t.precipitation_max AS precipitation_max,
    t.precipitation_min AS precipitation_min,
    t.frost_min AS frost_min,
    t.frost_max AS frost_max
  FROM
    tolerance t
  LEFT JOIN species s ON t.species_id = s.species_id
  LEFT JOIN genus g ON s.genus_id = g.genus_id
  LEFT JOIN controlled_vocabulary f ON t.fire_cv_id = f.controlled_vocabulary_id
  LEFT JOIN controlled_vocabulary st ON t.salinity_cv_id = st.controlled_vocabulary_id
  LEFT JOIN controlled_vocabulary sh ON t.shade_cv_id = sh.controlled_vocabulary_id
  LEFT JOIN controlled_vocabulary so ON t.soil_cv_id = so.controlled_vocabulary_id
);

-- INSERT/UPDATE FUNCTIONS
CREATE OR REPLACE FUNCTION insert_tolerance(
  tolerance_id_in UUID,
  genus_name_in TEXT,
  species_name_in TEXT,
  fire_in TEXT,
  salinity_in TEXT,
  shade_in TEXT,
  soil_in TEXT,
  precipitation_max_in INTEGER,
  precipitation_min_in INTEGER,
  frost_min_in INTEGER,
  frost_max_in INTEGER,
  source_name_in TEXT
) RETURNS void AS $$
DECLARE
  species_id UUID;
  fire_cv_id UUID;
  salinity_cv_id UUID;
  shade_cv_id UUID;
  soil_cv_id UUID;
BEGIN

  SELECT get_species_id(genus_name_in, species_name_in) INTO species_id;
  SELECT get_controlled_vocabulary_id('fire_resilience', fire_in) INTO fire_cv_id;
  SELECT get_controlled_vocabulary_id('salinity_tolerance', salinity_in) INTO salinity_cv_id;
  SELECT get_controlled_vocabulary_id('shade_tolerance', shade_in) INTO shade_cv_id;
  SELECT get_controlled_vocabulary_id('soil_tolerance', soil_in) INTO soil_cv_id;

  IF( tolerance_id_in IS NULL ) THEN
    SELECT uuid_generate_v4() INTO tolerance_id_in;
  END IF;
  SELECT get_source_id(source_name_in) INTO source_id;

  INSERT INTO tolerance (
    tolerance_id, species_id, fire_cv_id, salinity_cv_id, shade_cv_id, soil_cv_id, 
    precipitation_max, precipitation_min, frost_min, frost_max, source_id
  ) VALUES (
    tolerance_id_in, species_id, fire_cv_id, salinity_cv_id, shade_cv_id, soil_cv_id, 
    precipitation_max_in, precipitation_min_in, frost_min_in, frost_max_in, source_id
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_tolerance(
  tolerance_id_in UUID,
  genus_name_in TEXT,
  species_name_in TEXT,
  fire_in TEXT,
  salinity_in TEXT,
  shade_in TEXT,
  soil_in TEXT,
  precipitation_max_in INTEGER,
  precipitation_min_in INTEGER,
  frost_min_in INTEGER,
  frost_max_in INTEGER
) RETURNS void AS $$
DECLARE
  species_id UUID;
  fire_cv_id UUID;
  salinity_cv_id UUID;
  shade_cv_id UUID;
  soil_cv_id UUID;
BEGIN
  
    SELECT get_species_id(genus_name_in, species_name_in) INTO species_id;
    SELECT get_controlled_vocabulary_id('fire_resilience', fire_in) INTO fire_cv_id;
    SELECT get_controlled_vocabulary_id('salinity_tolerance', salinity_in) INTO salinity_cv_id;
    SELECT get_controlled_vocabulary_id('shade_tolerance', shade_in) INTO shade_cv_id;
    SELECT get_controlled_vocabulary_id('soil_tolerance', soil_in) INTO soil_cv_id;
  
    UPDATE tolerance SET (
      species_id, fire_cv_id, salinity_cv_id, shade_cv_id, soil_cv_id, 
      precipitation_max, precipitation_min, frost_min, frost_max
    ) = (
      species_id, fire_cv_id, salinity_cv_id, shade_cv_id, soil_cv_id, 
      precipitation_max_in, precipitation_min_in, frost_min_in, frost_max_in
    ) WHERE
      tolerance_id = tolerance_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION TRIGGERS
CREATE OR REPLACE FUNCTION tolerance_update_checks()
RETURNS TRIGGER AS $$
BEGIN
    -- Check that the controlled vocabulary values are valid
    -- this function will raise an exception if the value is not valid for type
    SELECT check_cv_id_of_type('fire_resilience', NEW.fire_cv_id);
    SELECT check_cv_id_of_type('salinity_tolerance', NEW.salinity_cv_id);
    SELECT check_cv_id_of_type('shade_tolerance', NEW.shade_cv_id);
    SELECT check_cv_id_of_type('soil_tolerance', NEW.soil_cv_id);

    IF NEW.precipitation_max < NEW.precipitation_min THEN
      RAISE EXCEPTION 'Precipitation max must be greater than or equal to precipitation min';
    END IF;

    IF NEW.frost_max < NEW.frost_min THEN
      RAISE EXCEPTION 'Frost max must be greater than or equal to frost min';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_tolerance_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_tolerance(
    tolerance_id_in := NEW.tolerance_id,
    genus_name_in := NEW.genus_name,
    species_name_in := NEW.species_name,
    fire_in := NEW.fire,
    salinity_in := NEW.salinity,
    shade_in := NEW.shade,
    soil_in := NEW.soil,
    precipitation_max_in := NEW.precipitation_max,
    precipitation_min_in := NEW.precipitation_min,
    frost_min_in := NEW.frost_min,
    frost_max_in := NEW.frost_max,
    source_name_in := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_tolerance_from_trig()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM update_tolerance(
    tolerance_id_in := NEW.tolerance_id,
    genus_name_in := NEW.genus_name,
    species_name_in := NEW.species_name,
    fire_in := NEW.fire,
    salinity_in := NEW.salinity,
    shade_in := NEW.shade,
    soil_in := NEW.soil,
    precipitation_max_in := NEW.precipitation_max,
    precipitation_min_in := NEW.precipitation_min,
    frost_min_in := NEW.frost_min,
    frost_max_in := NEW.frost_max
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

-- TRIGGERS
CREATE TRIGGER tolerance_update_checks_trigger
BEFORE INSERT OR UPDATE ON tolerance
FOR EACH ROW EXECUTE FUNCTION tolerance_update_checks();

CREATE TRIGGER tolerance_insert_trig
INSTEAD OF INSERT ON tolerance_view FOR EACH ROW
EXECUTE PROCEDURE insert_tolerance_from_trig();

CREATE TRIGGER tolerance_update_trig
INSTEAD OF UPDATE ON tolerance_view FOR EACH ROW
EXECUTE PROCEDURE update_tolerance_from_trig();