CREATE TABLE IF NOT EXISTS controlled_vocabulary_property (
  property_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pgdm_source_id UUID REFERENCES pgdm_source NOT NULL,
  property_input_id UUID NOT NULL,
  species_id UUID REFERENCES species(species_id),
  species_organ_id UUID REFERENCES species_organ(species_organ_id),
  controlled_vocabulary_id UUID REFERENCES controlled_vocabulary(controlled_vocabulary_id),
  publication_id UUID REFERENCES publication(publication_id),
  website_id UUID REFERENCES website(website_id),
  accessed DATE NOT NULL
);
CREATE INDEX IF NOT EXISTS property_source_id_idx ON controlled_vocabulary_property(pgdm_source_id);
CREATE INDEX IF NOT EXISTS property_species_id_idx ON controlled_vocabulary_property(species_id);
CREATE INDEX IF NOT EXISTS property_species_organ_id_idx ON controlled_vocabulary_property(species_organ_id);
CREATE INDEX IF NOT EXISTS property_controlled_vocabulary_id_idx ON controlled_vocabulary_property(controlled_vocabulary_id);
CREATE INDEX IF NOT EXISTS property_publication_id_idx ON controlled_vocabulary_property(publication_id);
CREATE INDEX IF NOT EXISTS property_website_id_idx ON controlled_vocabulary_property(website_id);
CREATE INDEX IF NOT EXISTS property_accessed_idx ON controlled_vocabulary_property(accessed);

CREATE OR REPLACE VIEW controlled_vocabulary_property_view AS
  SELECT
    cvp.property_id AS property_id,
    g.name AS genus_name,
    s.name AS species_name,
    o.name AS organ_name,
    cv.type AS property,
    cv.value AS value,
    p.publication_id AS publication_id,
    p.title AS publication_title,
    w.website_id AS website_id,
    w.url AS website_url,
    cvp.accessed AS accessed
  FROM controlled_vocabulary_property cvp
  LEFT JOIN controlled_vocabulary_view cv ON cvp.controlled_vocabulary_id = cv.controlled_vocabulary_id
  LEFT JOIN species s ON cvp.species_id = s.species_id
  LEFT JOIN genus g ON s.genus_id = g.genus_id
  LEFT JOIN species_organ so ON cvp.species_organ_id = so.species_organ_id
  LEFT JOIN organ o ON so.organ_id = o.organ_id
  LEFT JOIN publication p ON cvp.publication_id = p.publication_id
  LEFT JOIN website w ON cvp.website_id = w.website_id;

CREATE OR REPLACE VIEW cv_property_by_zone AS
  SELECT
    g.name AS genus_name,
    s.name AS species_name,
    o.name AS organ_name,
    cv.type AS property,
    array_agg(DISTINCT cv.value) AS value
  FROM controlled_vocabulary_property cvp
  LEFT JOIN controlled_vocabulary_view cv ON cvp.controlled_vocabulary_id = cv.controlled_vocabulary_id
  LEFT JOIN species s ON cvp.species_id = s.species_id
  LEFT JOIN genus g ON s.genus_id = g.genus_id
  LEFT JOIN species_organ so ON cvp.species_organ_id = so.species_organ_id
  LEFT JOIN organ o ON so.organ_id = o.organ_id
  GROUP BY g.name, s.name, o.name, cv.type;