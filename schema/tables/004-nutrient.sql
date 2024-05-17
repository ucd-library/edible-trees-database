

CREATE TABLE IF NOT EXISTS nutrient (
  nutrient_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  common_name TEXT NOT NULL UNIQUE,
  unit_id UUID NOT NULL REFERENCES unit(unit_id),
  min_bound INTEGER,
  max_bound INTEGER
);

-- DO we want to relate organs to nutrients?
-- CREATE TABLE IF NOT EXISTS species_nutrient (
--   species_nutrient UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   species_id UUID NOT NULL REFERENCES species(species_id),
--   nutrient_id UUID NOT NULL REFERENCES nutrient(nutrient_id),
--   value INTEGER NOT NULL
-- );

CREATE TABLE IF NOT EXISTS species_organ_nutrient (
  species_organ_nutrient_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  common_name_id UUID NOT NULL REFERENCES common_name(common_name_id),
  organ_id UUID NOT NULL REFERENCES organ(organ_id),
  nutrient_id UUID NOT NULL REFERENCES nutrient(nutrient_id),
  value INTEGER NOT NULL,
  UNIQUE (common_name_id, organ_id, nutrient_id)
);

CREATE OR REPLACE VIEW species_organ_nutrient_view AS
  SELECT
    g.name AS genus_name,
    g.genus_id AS genus_id,
    s.name AS species_name,
    s.species_id AS species_id,
    o.name AS organ_name,
    o.organ_id AS organ_id,
    cn.name AS common_name_name,
    cn.common_name_id AS common_name_id,
    n.common_name AS nutrient_name,
    n.nutrient_id AS nutrient_id,
    n.min_bound AS min_bound,
    n.max_bound AS max_bound,
    son.value AS value
  FROM species_organ_nutrient son
  LEFT JOIN common_name cn ON son.common_name_id = cn.common_name_id
  LEFT JOIN species s ON cn.species_id = s.species_id
  LEFT JOIN genus g ON s.genus_id = g.genus_id
  LEFT JOIN organ o ON son.organ_id = o.organ_id
  LEFT JOIN nutrient n ON son.nutrient_id = n.nutrient_id;


CREATE OR REPLACE FUNCTION check_nutrient_min_max_bounds()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.min_bound <= NEW.max_bound THEN
    RAISE EXCEPTION 'min_bound must be less than max_bound';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ 
BEGIN
  CREATE TRIGGER ensure_min_max_bounds
  BEFORE INSERT OR UPDATE ON nutrient
  FOR EACH ROW
  EXECUTE FUNCTION check_nutrient_min_max_bounds();
EXCEPTION
  WHEN duplicate_object THEN
    -- Handle the exception here
    RAISE NOTICE 'The trigger ensure_min_max_bounds already exists.';
END $$;

CREATE OR REPLACE FUNCTION check_species_nutrient_value()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.value >= (SELECT min_bound FROM nutrient WHERE nutrient_id = NEW.nutrient_id) OR
     NEW.value <= (SELECT max_bound FROM nutrient WHERE nutrient_id = NEW.nutrient_id) THEN
    RAISE EXCEPTION 'species_nutrient.value must be within min_bound and max_bound';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ 
BEGIN
  CREATE TRIGGER ensure_species_nutrient_value
  BEFORE INSERT OR UPDATE ON species_organ_nutrient
  FOR EACH ROW
  EXECUTE FUNCTION check_species_nutrient_value();
EXCEPTION
  WHEN duplicate_object THEN
    -- Handle the exception here
    RAISE NOTICE 'The trigger ensure_species_nutrient_value already exists.';
END $$;

CREATE OR REPLACE FUNCTION ensure_nutrient(
  common_name_in TEXT,
  unit_name_in TEXT,
  min_bound_in INTEGER,
  max_bound_in INTEGER
) RETURNS VOID AS $$
DECLARE
  uid UUID;
  nid UUID;
  sid UUID;
BEGIN
  SELECT get_unit_id(unit_name) INTO uid;

  SELECT nutrient_id INTO nid FROM nutrient WHERE common_name = common_name_in;
  IF nid IS NULL THEN
    INSERT INTO nutrient (common_name, unit_id, min_bound, max_bound) VALUES (common_name_in, uid, min_bound_in, max_bound_in) RETURNING nutrient_id INTO nid;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_nutrient_id(nutrient_name_in TEXT)
RETURNS UUID AS $$
DECLARE
  nid UUID;
BEGIN
  SELECT nutrient_id INTO nid FROM nutrient WHERE common_name = nutrient_name_in;
  IF nid IS NULL THEN
    RAISE EXCEPTION 'Nutrient % does not exist', nutrient_name_in;
  END IF;
  RETURN nid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_species_organ_nutrient(
  genus_name_in TEXT,
  species_name_in TEXT,
  common_name_in TEXT,
  organ_name_in TEXT,
  nutrient_name_in TEXT,
  value INTEGER
) RETURNS UUID AS $$
DECLARE
  sid UUID;
  oid UUID;
  nid UUID;
  qid UUID;
BEGIN

  SELECT get_species_id(genus_name_in, species_name_in, common_name_in) INTO sid;
  SELECT get_organ_id(organ_name_in) INTO oid;
  SELECT get_nutrient_id(nutrient_name_in) INTO nid;

  INSERT INTO species_organ_nutrient (common_name_id, organ_id, nutrient_id, value)
  VALUES (sid, oid, nid, value)
  RETURNING species_organ_nutrient_id INTO qid;

  RETURN qid;
END;
$$ LANGUAGE plpgsql;

