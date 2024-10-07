CREATE TABLE IF NOT EXISTS data_source_publication (
  data_source_publication_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_id UUID REFERENCES pgdm_source NOT NULL,
  doi text UNIQUE,
  author NOT NULL TEXT,
  title NOT NULL TEXT,
  journal TEXT,
  year NOT NULL INTERGER,
  volume INTERGER,
  issue INTERGER,
  page_start INTERGER,
  page_end INTERGER,
  stable_url TEXT,
);
CREATE INDEX data_source_publication_doi_idx ON data_source_publication(doi);

CREATE TABLE IF NOT EXISTS data_source_website (
  data_source_website_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_id UUID REFERENCES pgdm_source NOT NULL,
  url text UNIQUE,
  title NOT NULL TEXT,
  description TEXT
);

CREATE TABLE IF NOT EXISTS data_sources_access (
  source_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  data_source_website_id UUID REFERENCES data_source_website(data_source_website_id),
  data_source_publication_id UUID REFERENCES data_source_publication(data_source_publication_id),
  accessed DATE,
  UNIQUE(data_source_website_id, data_source_publication_id, accessed)
);

CREATE OR REPLACE FUNCTION get_or_insert_data_access_id(
  publication_doi TEXT,
  website_url TEXT,
  accessed DATE
) RETURNS UUID AS $$
DECLARE
  website_id UUID;
  publication_id UUID;
  source_id UUID;
BEGIN

  IF accessed IS NULL THEN
    RAISE EXCEPTION 'accessed date must be set';
  END IF;

  IF website_url IS NOT NULL THEN
    SELECT data_source_website_id INTO website_id 
    FROM data_source_website WHERE url = website_url;
    IF website_id IS NULL THEN
      RAISE EXCEPTION 'Website URL not found';
    END IF;
  ELSE IF publication_doi IS NOT NULL THEN
    SELECT data_source_publication_id INTO publication_id 
    FROM data_source_publication WHERE doi = publication_doi;
    IF publication_id IS NULL THEN
      RAISE EXCEPTION 'Publication DOI not found';
    END IF;
  ELSE
    RAISE EXCEPTION 'Either website_url or publication_doi must be set';
  END IF;

  SELECT 
    source_id INTO source_id 
  FROM data_sources_access 
  WHERE 
    (data_source_website_id = website_id OR 
    data_source_publication_id = publication_id) AND
    accessed = accessed;

  IF source_id IS NULL THEN
    INSERT INTO 
      data_sources_access (data_source_website_id, data_source_publication_id, accessed) 
    VALUES (website_id, publication_id, accessed) 
    RETURNING source_id INTO source_id;
  END IF;

  RETURN source_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION check_data_source_access() 
RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.data_source_website_id IS NULL AND NEW.data_source_publication_id IS NULL) OR 
     (NEW.data_source_website_id IS NOT NULL AND NEW.data_source_publication_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Either data_source_website_id or data_source_publication_id must be set, but not both';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_data_source_access
BEFORE INSERT OR UPDATE ON data_sources_access
FOR EACH ROW EXECUTE FUNCTION check_data_source_access();