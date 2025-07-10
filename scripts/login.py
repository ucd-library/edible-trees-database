import psycopg2
conn = psycopg2.connect(service='pgfarm', database='library/edible-trees')

# alternate connection method using parameters 
# conn = psycopg2.connect(
#   user='pjsin',
#   host='pgfarm.library.ucdavis.edu',
#   port=5432,
#   database='library/edible-trees',
#   password='HBsD0yqPKMZhDZSaS04c8A==',
#   sslmode='verify-full',
#   sslrootcert='system'
# )