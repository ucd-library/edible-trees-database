-- TABLE
DROP TABLE IF EXISTS website CASCADE;
CREATE TABLE website (
  website_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  url TEXT NOT NULL UNIQUE,
  organization TEXT
);
CREATE INDEX website_source_id_idx ON website(pgdm_source_id);

-- VIEW
CREATE OR REPLACE VIEW website_view AS
  SELECT
    w.website_id AS website_id,
    w.name AS name,
    w.description as description,
    w.url as url,
    w.organization as organization,
    sc.name AS source_name
  FROM
    website w
LEFT JOIN pgdm_source sc ON w.pgdm_source_id = sc.pgdm_source_id;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION insert_website (
  website_id UUID,
  name TEXT,
  description TEXT,
  url TEXT,
  organization TEXT,
  source_name TEXT) RETURNS void AS $$   
DECLARE
  sid UUID;
BEGIN

  IF( website_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO website_id;
  END IF;
  SELECT get_source_id(source_name) INTO sid;

  INSERT INTO website (
    website_id, name, description, url, organization, pgdm_source_id
  ) VALUES (
    website_id, name, description, url, organization, sid
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_website (
  website_id_in UUID,
  name_in TEXT,
  description_in TEXT,
  url_in TEXT,
  organization_in TEXT) RETURNS void AS $$   
DECLARE

BEGIN

  UPDATE website SET (
    name, description, url, organization 
  ) = (
    name_in, description_in, url_in, organization_in
  ) WHERE
    website_id = website_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION TRIGGERS
CREATE OR REPLACE FUNCTION insert_website_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_website(
    website_id := NEW.website_id,
    name := NEW.name,
    description := NEW.description,
    url := NEW.url,
    organization := NEW.organization,
    source_name := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_website_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM update_website(
    website_id_in := NEW.website_id,
    name_in := NEW.name,
    description_in := NEW.description,
    url_in := NEW.url,
    organization_in := NEW.organization
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION GETTER
CREATE OR REPLACE FUNCTION get_website_id(url TEXT) RETURNS UUID AS $$   
DECLARE
  wid UUID;
BEGIN

  SELECT 
    website_id INTO wid 
  FROM 
    website w 
  WHERE 
    w.url = url;

  IF (wid IS NULL) THEN
    RAISE EXCEPTION 'Unknown website: %', url;
  END IF;
  
  RETURN wid;
END ; 
$$ LANGUAGE plpgsql;

-- RULES
CREATE TRIGGER website_insert_trig
  INSTEAD OF INSERT ON
  website_view FOR EACH ROW 
  EXECUTE PROCEDURE insert_website_from_trig();

CREATE TRIGGER website_update_trig
  INSTEAD OF UPDATE ON
  website_view FOR EACH ROW 
  EXECUTE PROCEDURE update_website_from_trig();