set search_path to 'api';

CREATE OR REPLACE VIEW genus AS
  SELECT * FROM edible_trees.genus;

CREATE OR REPLACE VIEW species AS
  SELECT 
    s.species_id,
    s.genus_name,
    s.species_name
  FROM edible_trees.species_view s;