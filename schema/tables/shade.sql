
CREATE TABLE IF NOT EXISTS shade (
  shade_tolerance UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
   name TEXT NOT NULL UNIQUE
);

-- join shade tolerance, species, species id, and common name into a view
CREATE OR REPLACE VIEW shade_view AS
  SELECT
    s.name AS species_name,
    s.species_id AS species_id,
    cn.name AS common_name,
    cn.common_name_id AS common_name_id,
    shade.tolerance AS shade_tolerance
  FROM species s 
  JOIN shade 
