#! /bin/bash

set -e

PGSERVICE=$1
ROOT_DATA_FOLDER=$2
if [[ -z $PGSERVICE || -z $ROOT_DATA_FOLDER ]]; then
  echo "Usage: $0 <pgservice> <root-data-repo>"
  exit -1
fi

if [[ "$ROOT_DATA_FOLDER" != /* ]]; then
  ROOT_DATA_FOLDER="$(pwd)/$ROOT_DATA_FOLDER"
fi

export SCHEMA=edible_trees;
# export PGHOST=localhost;
export PGOPTIONS="--search_path=$SCHEMA,public"
PSQL="psql -U postgres"
USER="-u postgres"

pgdm insert -s "$PGSERVICE" $USER -t genus_view -f $ROOT_DATA_FOLDER/sheets/schema/genus.csv || true
pgdm insert -s "$PGSERVICE" $USER -t species_view -f $ROOT_DATA_FOLDER/sheets/schema/species.csv || true
pgdm insert -s "$PGSERVICE" $USER -t organ_view -f $ROOT_DATA_FOLDER/sheets/schema/organ.csv || true
pgdm insert -s "$PGSERVICE" $USER -t species_organ_view -f $ROOT_DATA_FOLDER/sheets/schema/species_organ.csv || true
pgdm insert -s "$PGSERVICE" $USER -t unit_view -f $ROOT_DATA_FOLDER/sheets/schema/unit.csv || true
pgdm insert -s "$PGSERVICE" $USER -t measurement_view -f $ROOT_DATA_FOLDER/sheets/schema/measurement.csv || true

pgdm insert -s "$PGSERVICE" $USER -t publication_view -f $ROOT_DATA_FOLDER/sheets/schema/data_source_publication.csv || true
pgdm insert -s "$PGSERVICE" $USER -t website_view -f $ROOT_DATA_FOLDER/sheets/schema/data_source_website.csv || true

for file in "$ROOT_DATA_FOLDER"/sheets/controlled_vocabulary/*; do
  if [[ -f $file ]]; then
    pgdm insert -s "$PGSERVICE" $USER  -t controlled_vocabulary_view -f $file || true
  fi
done

pgdm insert -s "$PGSERVICE" $USER -t properties_input -f "$ROOT_DATA_FOLDER/sheets/species_data/Acca sellowiana.csv"