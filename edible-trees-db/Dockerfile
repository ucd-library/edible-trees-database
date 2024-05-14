FROM postgres:14

RUN apt-get update \
      && apt-get install -y --no-install-recommends \
        postgis \
        postgresql-14-postgis-3 \
        postgresql-14-postgis-3-scripts \
      && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./initdb-postgis.sql /docker-entrypoint-initdb.d/postgis.sql