

-- DO we want to relate organs to nutrients?
-- CREATE TABLE IF NOT EXISTS species_nutrient (
--   species_nutrient UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   species_id UUID NOT NULL REFERENCES species(species_id),
--   nutrient_id UUID NOT NULL REFERENCES nutrient(nutrient_id),
--   value INTEGER NOT NULL
-- );

CREATE TABLE IF NOT EXISTS species_organ_nutrient (
  species_organ_nutrient_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  species_id UUID NOT NULL REFERENCES species(species_id),
  organ_cv_id UUID NOT NULL REFERENCES controlled_vocabulary(controlled_vocabulary_id),
  nutrient_id UUID NOT NULL REFERENCES nutrient(nutrient_id),
  preparation_cv_id UUID REFERENCES controlled_vocabulary(controlled_vocabulary_id),
  toxicity_cv_id UUID REFERENCES controlled_vocabulary(controlled_vocabulary_id),
  source_id UUID NOT NULL REFERENCES source(source_id), -- not sure about the null, because the nutreit can be null, but if it is not null need to make sure it has a source.
  proxy BOOLEAN NOT NULL DEFAULT TRUE,
  proxy_species_id REFERENCES species(species_id), -- not sure if this is the right way to do this. Need to reference another species that MAY be the in data base or may be an outside species...
  -- notes_id UUID REFERENCES notes(notes_id),
  value INTEGER,
  UNIQUE (species_id, organ_id, nutrient_id)
);

CREATE OR REPLACE VIEW species_organ_nutrient_view AS
  SELECT
    g.name AS genus_name,
    s.name AS species_name,
    o.name AS organ_name,
    n.name AS nutrient_name,
    n.unit AS nutrient_unit,
    n.min_bound AS nutrient_min_bound, -- JM: Demo, is needed?
    n.max_bound AS nutrient_max_bound,
    p.value AS species_preparation,
    t.value AS species_toxicity,
    son.value AS value,
    son.proxy AS is_proxy,
    sp.species_id AS proxy_species_id,
    gp.name AS proxy_genus_name,
    sp.name AS proxy_species_name
  FROM
    species_organ_nutrient son
  LEFT JOIN species s ON son.species_id = s.species_id
  LEFT JOIN genus g ON s.genus_id = g.genus_id
  LEFT JOIN controlled_vocabulary o ON son.organ_cv_id = o.controlled_vocabulary_id;
  LEFT JOIN nutrient_view n ON son.nutrient_id = n.nutrient_id;
  LEFT JOIN controlled_vocabulary p ON son.preparation_cv_id = p.controlled_vocabulary_id;
  LEFT JOIN controlled_vocabulary t ON son.toxicity_cv_id = t.controlled_vocabulary_id
  LEFT JOIN son.proxy_species_id ON species sp ON son.proxy_species_id = sp.species_id
  LEFT JOIN genus gp ON sp.genus_id = gp.genus_id;


-- FFAR spreadsheet insert view
CREATE OR REPLACE VIEW ffar_view AS
  SELECT
    genus_name as "Genus",
    species_name as "Species",
    common_name as "Common Name",
    nutrient_name as "Nutrient Name",
    unit_name as "Nutrient Unit",
    min_bound as "Min",
    max_bound as "Max",
    value as "Amount"
  FROM species_organ_nutrient_view;

CREATE OR REPLACE FUNCTION insert_ffar_view()
  RETURNS TRIGGER AS $$
  BEGIN
    -- Note, this uses ensure, which assumes the data is trustworthy and you should add values if they don't exist
    -- If this view was for student input, you would just want to get the id via get_species_id(genus, species, common_name)
    -- or just dont call first two functions at all and just insert the data.  The add_species_organ_nutrient function 
    -- error out if the species, organ or nutrient does not exist
    -- SELECT * FROM ensure_species_exists(NEW."Genus", NEW."Species", NEW."Common Name");

    -- SELECT * FROM ensure_nutrient(NEW."Nutrient Name", NEW."Nutrient Unit", NEW."Min", NEW."Max");

    SELECT * FROM add_species_organ_nutrient(NEW."Genus", NEW."Species", NEW."Common Name", NEW."Organ", NEW."Nutrient Name", NEW."Amount");
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;

CREATE TRIGGER insert_ffar_view_trigger
INSTEAD OF INSERT ON ffar_view
FOR EACH ROW
EXECUTE FUNCTION insert_ffar_view();


CREATE OR REPLACE FUNCTION species_organ_nutrient_update_checks()
RETURNS TRIGGER AS $$
BEGIN
 
  SELECT check_cv_id_of_type('organ', NEW.organ_cv_id);
  SELECT check_cv_id_of_type('species_preparation', NEW.preparation_cv_id);
  SELECT check_cv_id_of_type('species_toxicity', NEW.toxicity_cv_id);

  IF NEW.value < (SELECT min_bound FROM nutrient WHERE nutrient_id = NEW.nutrient_id) OR
     NEW.value > (SELECT max_bound FROM nutrient WHERE nutrient_id = NEW.nutrient_id) THEN
    RAISE EXCEPTION 'species_organ_nutrient.value must be within min_bound and max_bound';
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

  SELECT get_species_id(genus_name_in, species_name_in) INTO sid;
  SELECT get_organ_id(organ_name_in) INTO oid;
  SELECT get_nutrient_id(nutrient_name_in) INTO nid;

  INSERT INTO species_organ_nutrient (species_id, organ_id, nutrient_id, value)
  VALUES (sid, oid, nid, value)
  RETURNING species_organ_nutrient_id INTO qid;

  RETURN qid;
END;
$$ LANGUAGE plpgsql;