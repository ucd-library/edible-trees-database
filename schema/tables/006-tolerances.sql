CREATE OR REPLACE species_tolerance_by_source AS
  SELECT 
    g.name AS genus_name,
    s.name AS species_name,
    z.usda_zone_id AS usda_zone_id,
    ARRAY_AGG(DISTINCT shade.controlled_vocabulary_value) AS shade_tolerances,
    ARRAY_AGG(DISTINCT shade.data_source) AS shade_data_source,
    ARRAY_AGG(DISTINCT soil.controlled_vocabulary_value) AS soil_tolerances,
    ARRAY_AGG(DISTINCT soil.data_source) AS soil_data_source,
    ARRAY_AGG(DISTINCT fire.controlled_vocabulary_value) AS fire_resilience,
    ARRAY_AGG(DISTINCT fire.data_source) AS fire_data_source,
    ARRAY_AGG(DISTINCT salinity.controlled_vocabulary_value) AS salinity_tolerances,
    ARRAY_AGG(DISTINCT salinity.data_source) AS salinity_data_source,
    precipitation_min.measurement_value AS precipitation_min,
    precipitation_min.measurement_unit AS precipitation_min_unit,
    precipitation_min.data_source AS precipitation_min_data_source,
    precipitation_max.measurement_value AS precipitation_max,
    precipitation_max.measurement_unit AS precipitation_max_unit,
    precipitation_max.data_source AS precipitation_max_data_source,
    frost_min.measurement_value AS frost_min,
    frost_min.measurement_unit AS frost_min_unit,
    frost_min.data_source AS frost_min_data_source,
    frost_max.measurement_value AS frost_max
    frost_max.measurement_unit AS frost_max_unit,
    frost_max.data_source AS frost_max_data_source
  FROM species s, usda_zone z
  LEFT JOIN genus g ON s.genus_id = g.genus_id
  LEFT JOIN property_view shade ON s.species_id = so.species_id AND 
                        z.usda_zone_id = shade.usda_zone_id AND
                        p.controlled_vocabulary_type = 'shade_tolerance'
  LEFT JOIN property_view soil ON s.species_id = so.species_id AND
                        z.usda_zone_id = soil.usda_zone_id AND 
                        p.controlled_vocabulary_type = 'soil_tolerance'
  LEFT JOIN property_view fire ON s.species_id = so.species_id AND 
                        z.usda_zone_id = fire.usda_zone_id ANDs
                        p.controlled_vocabulary_type = 'fire_resilience'
  LEFT JOIN property_view salinity ON s.species_id = so.species_id AND 
                        z.usda_zone_id = salinity.usda_zone_id AND
                        p.controlled_vocabulary_type = 'salinity_tolerance',
  LEFT JOIN property_view precipitation_min ON s.species_id = so.species_id AND 
                        z.usda_zone_id = precipitation_min.usda_zone_id AND
                        p.measurement_name = 'precipitation_min',
  LEFT JOIN property_view precipitation_max ON s.species_id = so.species_id AND
                        z.usda_zone_id = precipitation_max.usda_zone_id AND 
                        p.measurement_name = 'precipitation_max',
  LEFT JOIN property_view frost_min ON s.species_id = so.species_id AND 
                        z.usda_zone_id = frost_min.usda_zone_id AND
                        p.measurement_name = 'frost_min',
  LEFT JOIN property_view frost_max ON s.species_id = so.species_id AND
                        z.usda_zone_id = frost_max.usda_zone_id AND 
                        p.measurement_name = 'frost_max',
  GROUP BY g.name, s.name, z.usda_zone_id, precipitation_min.measurement_value, 
           precipitation_max.measurement_value, frost_min.measurement_value, 
           frost_max.measurement_value, precipitation_min.data_source,
            precipitation_max.data_source, frost_min.data_source,
            frost_max.data_source;
