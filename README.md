# edible-trees-database

# Requirements

- Docker/Docker Compose
- git

# Get the code

```bash
git clone https://github.com/ucd-library/edible-trees-database
cd edible-trees-database
```

# Start the database

```bash
cd edible-trees-db
docker compose up -d
```

if you need to restore the schema, run the following command:

```bash
cd edible-trees-db
docker compose exec pg /sql/init.sh
```

# Stop the database

```bash
cd edible-trees-db
docker compose down
```

or if you want to remove all data and start fresh:

```bash
cd edible-trees-db
docker compose down -v
```

# Access the database

From bash terminal:

```bash
cd edible-trees-db
docker compose exec pg psql -U postgres
```

From R code (using RPostgres):

```R
library(DBI)
library(RPostgres)

con <- dbConnect(RPostgres::Postgres(), dbname = "postgres", user = "postgres", host = "localhost", port = 5432, password = "postgres")

query <- "SELECT * FROM edible_trees.species_view LIMIT 10"
result <- dbGetQuery(con, query)

# Display the result
print(result)
```

From Python code (using psycopg2):

```python
import psycopg2

# Create a connection object
try:
    con = psycopg2.connect(
        host="localhost",
        port=5432,
        dbname="postgres",
        user="postgres",
        # never hardcode real passwords in code!
        password="postgres"
    )

    # Create a cursor object
    cur = con.cursor()

    # Example: Get the first 10 rows from a table
    query = "SELECT * FROM edible_trees.species_view LIMIT 10"
    cur.execute(query)

    # Fetch and display the result
    result = cur.fetchall()
    for row in result:
        print(row)

    # Close the cursor and connection
    cur.close()
    con.close()

except Exception as e:
    print(f"An error occurred: {e}")
```