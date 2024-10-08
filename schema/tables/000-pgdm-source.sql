-- TABLES
CREATE TABLE IF NOT EXISTS pgdm_tables (
  table_view TEXT PRIMARY KEY,
  uid TEXT NOT NULL,
  name TEXT NOT NULL UNIQUE,
  delete_view BOOLEAN
);

DO $$ 
BEGIN
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('genus_view', 'genus', 'genus_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('species_view', 'species', 'species_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('usda_zone_view', 'usda_zone', 'usda_zone_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('data_source_publication', 'data_source_publication', 'data_source_publication_id');
  INSERT INTO pgdm_tables (table_view, name, uid) VALUES ('data_source_website', 'data_source_website', 'data_source_website_id');
EXCEPTION
  WHEN UNIQUE_VIOLATION THEN
    -- Handle the exception here
    RAISE NOTICE 'The pgdm_tables already initialized.';
END $$;

-- TABLE
CREATE TABLE IF NOT EXISTS pgdm_source (
  pgdm_source_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  revision INTEGER NOT NULL,
  table_view text REFERENCES pgdm_tables
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