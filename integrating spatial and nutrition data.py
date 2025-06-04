CREATE TABLE species_traits (
    property_input_id UUID PRIMARY KEY,
    genus_name TEXT,
    species_name TEXT,
    organ_name TEXT,
    values TEXT,
    type TEXT,
    unit TEXT,
    precision TEXT,
    uncertainty TEXT,
    data_source TEXT,
    accessed DATE,
    comments TEXT
);

#
COPY species_traits (
    property_input_id,
    genus_name,
    species_name,
    organ_name,
    values, -- Unquoted, matching the table definition
    type,
    unit,
    precision,
    uncertainty,
    data_source,
    accessed, -- This column is now DATE type
    comments
)
FROM 'C:/work/edible-trees-data/sheets/species_data/Juglans nigra.csv' 
WITH (FORMAT CSV, HEADER TRUE, DELIMITER ','); 