-- TABLE
CREATE TABLE IF NOT EXISTS publication (
  publication_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  doi TEXT NOT NULL UNIQUE,
  author TEXT NOT NULL,
  title TEXT NOT NULL,
  journal TEXT,
  year INTEGER,
  volume INTEGER,
  issue INTEGER,
  page_start INTEGER,
  page_end INTEGER,
  url TEXT
);
CREATE INDEX publication_source_id_idx ON publication(pgdm_source_id);
CREATE INDEX publication_doi_idx ON publication(doi);

-- VIEW
CREATE OR REPLACE VIEW publication_view AS
  SELECT
    p.publication_id AS publication_id,
    p.doi as doi,
    p.author as author,
    p.title as title,
    p.journal as journal,
    p.year as year,
    p.volume as volume,
    p.issue as issue,
    p.page_start as page_start,
    p.page_end as page_end,
    p.url as url,
    sc.name AS source_name
  FROM
    publication p
LEFT JOIN pgdm_source sc ON p.pgdm_source_id = sc.pgdm_source_id;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION insert_publication (
  publication_id UUID,
  doi TEXT,
  author TEXT,
  title TEXT,
  journal TEXT,
  year INTEGER,
  volume INTEGER,
  issue INTEGER,
  page_start INTEGER,
  page_end INTEGER,
  url TEXT,
  source_name TEXT) RETURNS void AS $$   
DECLARE
  sid UUID;
BEGIN

  IF( publication_id IS NULL ) THEN
    SELECT uuid_generate_v4() INTO publication_id;
  END IF;
  SELECT get_source_id(source_name) INTO sid;

  INSERT INTO publication (
    publication_id, doi, author, title, journal, year, volume, issue, page_start, page_end, url, pgdm_source_id
  ) VALUES (
    publication_id, doi, author, title, journal, year, volume, issue, page_start, page_end, url, sid
  );

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_publication (
  publication_id_in UUID,
  doi_in TEXT,
  author_in TEXT,
  title_in TEXT,
  journal_in TEXT,
  year_in INTEGER,
  volume_in INTEGER,
  issue_in INTEGER,
  page_start_in INTEGER,
  page_end_in INTEGER,
  url_in TEXT) RETURNS void AS $$   
DECLARE

BEGIN

  UPDATE publication SET (
    doi, author, title, journal, year, volume, issue, page_start, page_end, url 
  ) = (
    doi_in, author_in, title_in, journal_in, year_in, volume_in, issue_in, page_start_in, page_end_in, url_in
  ) WHERE
    publication_id = publication_id_in;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION TRIGGERS
CREATE OR REPLACE FUNCTION insert_publication_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM insert_publication(
    publication_id := NEW.publication_id,
    doi := NEW.doi,
    author := NEW.author,
    title := NEW.title,
    journal := NEW.journal,
    year := NEW.year,
    volume := NEW.volume,
    issue := NEW.issue,
    page_start := NEW.page_start,
    page_end := NEW.page_end,
    url := NEW.url,
    source_name := NEW.source_name
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_publication_from_trig() 
RETURNS TRIGGER AS $$   
BEGIN
  PERFORM update_publication(
    publication_id_in := NEW.publication_id,
    doi_in := NEW.doi,
    author_in := NEW.author,
    title_in := NEW.title,
    journal_in := NEW.journal,
    year_in := NEW.year,
    volume_in := NEW.volume,
    issue_in := NEW.issue,
    page_start_in := NEW.page_start,
    page_end_in := NEW.page_end,
    url_in := NEW.url
  );
  RETURN NEW;

EXCEPTION WHEN raise_exception THEN
  RAISE;
END; 
$$ LANGUAGE plpgsql;

-- FUNCTION GETTER
CREATE OR REPLACE FUNCTION get_publication_id(doi TEXT) RETURNS UUID AS $$   
DECLARE
  pid UUID;
BEGIN

  SELECT 
    publication_id INTO pid 
  FROM 
    publication p 
  WHERE  
    p.doi = doi;

  IF (pid IS NULL) THEN
    RAISE EXCEPTION 'Unknown publication: %', doi;
  END IF;
  
  RETURN pid;
END ; 
$$ LANGUAGE plpgsql;

-- RULES
CREATE TRIGGER publication_insert_trig
  INSTEAD OF INSERT ON
  publication_view FOR EACH ROW 
  EXECUTE PROCEDURE insert_publication_from_trig();

CREATE TRIGGER publication_update_trig
  INSTEAD OF UPDATE ON
  publication_view FOR EACH ROW 
  EXECUTE PROCEDURE update_publication_from_trig();