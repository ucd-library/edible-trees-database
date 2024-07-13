#! /bin/bash

# Never run this unless you mean to.
# exit -1;

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR

SCHEMA=edible_trees;
export PGHOST=localhost;
export PGUSER=postgres;

psql -c "CREATE SCHEMA IF NOT EXISTS $SCHEMA;"
psql -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
export PGOPTIONS=--search_path=$SCHEMA,public

# types
psql -f ./tables/enums/qa_status.sql

# tables make sure when you add tables to put them in order
psql -f ./tables/001-species.sql
psql -f ./tables/002-organ.sql
psql -f ./tables/003-unit.sql
psql -f ./tables/004-nutrient.sql
psql -f ./tables/toxicity.sql
psql -f ./tables/preparation.sql
psql -f ./tables/species_organ_nutrient.sql


psql -f ./tables/005-qa.sql
psql -f ./tables/bloom.sql
psql -f ./tables/color.sql
psql -f ./tables/harvest.sql
psql -f ./tables/phenotype.sql


psql -f ./tables/salinity.sql
psql -f ./tables/shade.sql
psql -f ./tables/soil.sql
psql -f ./tables/fire.sql
psql -f ./tables/usda_zone.sql
psql -f ./tables/tolerances.sql


psql -f ./tables/notes.sql
psql -f ./tables/sources.sql