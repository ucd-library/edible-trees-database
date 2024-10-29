#! /bin/bash

# Never run this unless you mean to.
# exit -1;

set -e

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR

SCHEMA=edible_trees;
export PGHOST=localhost;
# export PGUSER=postgres
PSQL="psql -U postgres"
# export PGSERVICE=pgfarm
# export PGDATABASE="library/edible-trees"

$PSQL -c "CREATE SCHEMA IF NOT EXISTS $SCHEMA;"
$PSQL -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
export PGOPTIONS=--search_path=$SCHEMA,public

# types
# psql -f ./tables/enums/qa_status.sql

# tables make sure when you add tables to put them in order
$PSQL -f ./tables/000-pgdm-source.sql
$PSQL -f ./tables/001-controlled-vocabulary.sql
$PSQL -f ./tables/001-genus.sql
$PSQL -f ./tables/001-organ.sql
$PSQL -f ./tables/001-unit.sql
$PSQL -f ./tables/001-usda-zone.sql
$PSQL -f ./tables/002-species.sql