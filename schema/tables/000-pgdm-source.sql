-- TABLES
CREATE TABLE IF NOT EXISTS pgdm_tables (
  table_view TEXT PRIMARY KEY,
  uid TEXT NOT NULL,
  name TEXT NOT NULL UNIQUE,
  delete_view TEXT
);

DO $$ 
BEGIN
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('genus_view', 'genus', 'genus_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('unit_view', 'unit', 'unit_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('measurement_view', 'measurement', 'measurement_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('organ_view', 'organ', 'organ_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('species_view', 'species', 'species_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('common_name_view', 'common_name', 'common_name_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('controlled_vocabulary_view', 'controlled_vocabulary', 'controlled_vocabulary_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('species_organ_view', 'species_organ', 'species_organ_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('usda_zone_view', 'usda_zone', 'usda_zone_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('publication_view', 'publication', 'publication_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('website_view', 'website', 'website_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('properties_input', 'properties_input', 'property_input_id');
EXCEPTION
  WHEN UNIQUE_VIOLATION THEN
    -- Handle the exception here
    RAISE NOTICE 'The pgdm_tables already initialized.';
END $$;

-- CONFIG
CREATE TABLE IF NOT EXISTS pgdm_table_config (
  serial SERIAL PRIMARY KEY,
  table_name TEXT REFERENCES pgdm_tables(name) ON UPDATE CASCADE,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  UNIQUE (table_name, key)
);

DO $$ 
BEGIN
  INSERT INTO pgdm_table_config (table_name, key, value) VALUES ('properties_input', 'delete_column', 'source_name');
  INSERT INTO pgdm_table_config (table_name, key, value) VALUES ('properties_input', 'delete_column_type', 'name');
EXCEPTION
  WHEN UNIQUE_VIOLATION THEN
    -- Handle the exception here
    RAISE NOTICE 'The pgdm_config already initialized.';
END $$;

-- TABLE
CREATE TABLE IF NOT EXISTS pgdm_source (
  pgdm_source_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  revision INTEGER NOT NULL,
  table_view text REFERENCES pgdm_tables ON UPDATE CASCADE
);

-- FUNCTION GETTER
CREATE OR REPLACE FUNCTION get_source_id(source_name text) RETURNS UUID AS $$   
DECLARE
  sid UUID;
BEGIN
  select pgdm_source_id into sid from pgdm_source where name = source_name;

  if (sid is NULL) then
    RAISE EXCEPTION 'Unknown pgdm source: %', source_name;
  END IF;
  
  RETURN sid;
END ; 
$$ LANGUAGE plpgsql;