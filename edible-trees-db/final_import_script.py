#!/usr/bin/env python3
import pandas as pd
import psycopg2
from sqlalchemy import create_engine
import json
import os
import sys
from pathlib import Path
from psycopg2.extras import Json

# Database connection - local Docker PostgreSQL (no password needed due to trust auth)
DATABASE_URL = 'postgresql://postgres@localhost:5432/postgres'
# Try service first, if that doesn't work, we'll use direct connection
#DATABASE_URL = 'postgresql://pjsin:postgres@localhost:5432/library/edible-trees'

def setup_database():
    """Create tables and enable PostGIS"""
    print("Setting up database...")
    
    try:
        # Connect to local Docker PostgreSQL (trust auth, no password needed)
        conn = psycopg2.connect(
            host="localhost",
            database="postgres",
            user="postgres"
        )
        cur = conn.cursor()
        
        # Enable PostGIS
        cur.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
        
        # Drop existing tables if they exist (for clean import)
        cur.execute("DROP TABLE IF EXISTS species_climate_suitability CASCADE;")
        cur.execute("DROP TABLE IF EXISTS species_nutrition CASCADE;")
        cur.execute("DROP VIEW IF EXISTS species_complete CASCADE;")
        
        # Create nutrition table matching your CSV structure
        cur.execute("""
        CREATE TABLE species_nutrition (
            id SERIAL PRIMARY KEY,
            property_input_id VARCHAR(50),
            genus_name VARCHAR(100),
            species_name VARCHAR(100),
            organ_name VARCHAR(50),
            values_data DECIMAL,
            type_info VARCHAR(100),
            unit_info VARCHAR(50),
            precision_val DECIMAL,
            uncertainty_val DECIMAL,
            data_source TEXT,
            accessed_date DATE,
            comments TEXT
        );
        """)
        
        # Create climate suitability table (renamed from distribution)
        cur.execute("""
        CREATE TABLE species_climate_suitability (
            id SERIAL PRIMARY KEY,
            genus_name VARCHAR(100),
            species_name VARCHAR(100),
            climate_scenario VARCHAR(20),
            geometry geometry(GEOMETRY, 4326),
            metadata JSONB,
            created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(genus_name, species_name, climate_scenario)
        );
        """)
        
        # Create indexes
        cur.execute("CREATE INDEX idx_nutrition_species ON species_nutrition(genus_name, species_name);")
        cur.execute("CREATE INDEX idx_climate_species ON species_climate_suitability(genus_name, species_name);")
        cur.execute("CREATE INDEX idx_climate_geom ON species_climate_suitability USING GIST(geometry);")
        
        conn.commit()
        cur.close()
        conn.close()
        print("✅ Database setup complete")
        return True
        
    except Exception as e:
        print(f"❌ Database setup failed: {str(e)}")
        return False

def import_csv_data():
    """Import CSV nutrition data with exact column mapping"""
    print("\n--- Importing CSV Data ---")
    
    csv_path = '/mnt/c/work/edible-trees-data/sheets/species_data/'
    
    if not os.path.exists(csv_path):
        print(f"❌ CSV path not found: {csv_path}")
        return False
    
    csv_files = [f for f in os.listdir(csv_path) if f.endswith('.csv')]
    print(f"Found {len(csv_files)} CSV files")
    
    # For SQLAlchemy with local Docker PostgreSQL
    engine = create_engine(DATABASE_URL)
    print(f"  - Connected to local PostgreSQL database")
    total_records = 0
    success_files = 0
    
    for csv_file in csv_files:
        print(f"Processing {csv_file}...")
        
        try:
            # Read CSV
            df = pd.read_csv(os.path.join(csv_path, csv_file))
            print(f"  - Loaded {len(df)} rows")
            
            # Map CSV columns to database columns with flexible matching
            column_mapping = {}
            print(f"  - Available columns: {list(df.columns)}")
            
            for col in df.columns:
                col_clean = col.strip().lower().replace(':', '_').replace(' ', '_')
                
                # Handle the specific case of property_input_id:r0
                if col == 'property_input_id:r0' or 'property_input_id' in col:
                    column_mapping[col] = 'property_input_id'
                elif col == 'genus_name':
                    column_mapping[col] = 'genus_name'
                elif col == 'species_name':
                    column_mapping[col] = 'species_name'
                elif col == 'organ_name':
                    column_mapping[col] = 'organ_name'
                elif col == 'values':
                    column_mapping[col] = 'values_data'
                elif col == 'type':
                    column_mapping[col] = 'type_info'
                elif col == 'unit':
                    column_mapping[col] = 'unit_info'
                elif col == 'precision':
                    column_mapping[col] = 'precision_val'
                elif col == 'uncertainty':
                    column_mapping[col] = 'uncertainty_val'
                elif col == 'data_source':
                    column_mapping[col] = 'data_source'
                elif col == 'accessed':
                    column_mapping[col] = 'accessed_date'
                elif col == 'comments':
                    column_mapping[col] = 'comments'
            
            print(f"  - Column mapping: {column_mapping}")
            
            # Rename columns
            df = df.rename(columns=column_mapping)
            
            # Clean and convert data types
            if 'values_data' in df.columns:
                df['values_data'] = pd.to_numeric(df['values_data'], errors='coerce')
            
            if 'precision_val' in df.columns:
                df['precision_val'] = pd.to_numeric(df['precision_val'], errors='coerce')
            
            if 'uncertainty_val' in df.columns:
                df['uncertainty_val'] = pd.to_numeric(df['uncertainty_val'], errors='coerce')
            
            if 'accessed_date' in df.columns:
                df['accessed_date'] = pd.to_datetime(df['accessed_date'], errors='coerce')
            
            # Clean genus and species names (remove extra spaces, standardize case)
            if 'genus_name' in df.columns:
                df['genus_name'] = df['genus_name'].str.strip().str.title()
            
            if 'species_name' in df.columns:
                df['species_name'] = df['species_name'].str.strip().str.lower()
            
            # Keep only columns that exist in our table and were successfully mapped
            db_columns = ['property_input_id', 'genus_name', 'species_name', 'organ_name', 
                         'values_data', 'type_info', 'unit_info', 'precision_val', 
                         'uncertainty_val', 'data_source', 'accessed_date', 'comments']
            
            # Only keep mapped columns that exist in the database schema
            df_filtered = df[[col for col in df.columns if col in db_columns]]
            
            # Remove rows with missing essential data
            df_filtered = df_filtered.dropna(subset=['genus_name', 'species_name'], how='all')
            
            # Import to database
            records_imported = len(df_filtered)
            df_filtered.to_sql('species_nutrition', engine, if_exists='append', index=False)
            
            print(f"  - ✅ Imported {records_imported} records")
            total_records += records_imported
            success_files += 1
            
        except Exception as e:
            print(f"  - ❌ Error: {str(e)}")
            continue
    
    print(f"✅ CSV import complete!")
    print(f"   Files processed: {success_files}/{len(csv_files)}")
    print(f"   Total records: {total_records}")
    return True

def parse_geojson_filename(filename):
    """Parse species name from renamed GeoJSON files"""
    # Remove .geojson extension
    filename_base = filename.replace('.geojson', '')
    
    # Default climate scenario
    climate_scenario = 'current'
    
    # Check for climate scenario at the end
    if filename_base.lower().endswith(' current'):
        climate_scenario = 'current'
        filename_base = filename_base[:-8]  # Remove ' current'
    elif filename_base.lower().endswith(' future'):
        climate_scenario = 'future'
        filename_base = filename_base[:-7]  # Remove ' future'
    
    # Split genus and species by space
    if ' ' in filename_base:
        parts = filename_base.split(' ')
        if len(parts) >= 2:
            genus = parts[0].strip().title()
            species = ' '.join(parts[1:]).strip().lower()
            return genus, species, climate_scenario
    
    return None, None, None

def import_geojson_data():
    """Import GeoJSON climate suitability data"""
    print("\n--- Importing GeoJSON Climate Suitability Data ---")
    
    geojson_path = '/mnt/c/work/edible-trees-data/gis_data/'
    
    if not os.path.exists(geojson_path):
        print(f"❌ GeoJSON path not found: {geojson_path}")
        return False
    
    geojson_files = [f for f in os.listdir(geojson_path) if f.endswith('.geojson')]
    print(f"Found {len(geojson_files)} GeoJSON files")
    
    # Connect to local Docker PostgreSQL
    try:
        conn = psycopg2.connect(
            host="localhost",
            database="postgres",
            user="postgres"
        )
        cur = conn.cursor()
    except Exception as e:
        print(f"❌ Database connection failed: {str(e)}")
        print("💡 Hint: Make sure your Docker container is running: docker compose up -d")
        return False
    
    success_count = 0
    error_count = 0
    
    for geojson_file in geojson_files:
        print(f"Processing {geojson_file}...")
        
        try:
            # Parse filename
            genus, species, climate_scenario = parse_geojson_filename(geojson_file)
            
            if not all([genus, species]):
                print(f"  - ❌ Could not parse species from: {geojson_file}")
                error_count += 1
                continue
            
            print(f"  - Species: {genus} {species} ({climate_scenario} climate)")
            
            # Read GeoJSON
            with open(os.path.join(geojson_path, geojson_file), 'r', encoding='utf-8') as f:
                geojson_data = json.load(f)
            
            # Validate and potentially fix GeoJSON structure
            if geojson_data.get('type') == 'FeatureCollection':
                # Use the geometry from the first feature
                if geojson_data.get('features') and len(geojson_data['features']) > 0:
                    first_feature = geojson_data['features'][0]
                    if 'geometry' in first_feature:
                        # Create a simpler GeoJSON with just the geometry
                        simple_geojson = first_feature['geometry']
                        geojson_str = json.dumps(simple_geojson)
                    else:
                        print(f"  - ❌ No geometry found in first feature")
                        error_count += 1
                        continue
                else:
                    print(f"  - ❌ FeatureCollection has no features")
                    error_count += 1
                    continue
            elif geojson_data.get('type') == 'Feature':
                # Extract just the geometry
                if 'geometry' in geojson_data:
                    geojson_str = json.dumps(geojson_data['geometry'])
                else:
                    print(f"  - ❌ Feature has no geometry")
                    error_count += 1
                    continue
            elif geojson_data.get('type') in ['Polygon', 'MultiPolygon', 'Point', 'MultiPoint', 'LineString', 'MultiLineString']:
                # It's already a geometry object
                geojson_str = json.dumps(geojson_data)
            else:
                print(f"  - ❌ Unknown GeoJSON type: {geojson_data.get('type')}")
                error_count += 1
                continue
            
            # Extract metadata
            metadata = geojson_data.get('properties', {})
            if geojson_data.get('type') == 'FeatureCollection' and geojson_data.get('features'):
                first_feature = geojson_data['features'][0]
                if 'properties' in first_feature:
                    metadata.update(first_feature['properties'])
            
            # Insert into database
            insert_query = """
            INSERT INTO species_climate_suitability (genus_name, species_name, climate_scenario, geometry, metadata)
            VALUES (%s, %s, %s, ST_GeomFromGeoJSON(%s), %s)
            ON CONFLICT (genus_name, species_name, climate_scenario) DO UPDATE SET
            geometry = EXCLUDED.geometry,
            metadata = EXCLUDED.metadata;
            """
            
            cur.execute(insert_query, (genus, species, climate_scenario, geojson_str, Json(metadata)))
            
            print(f"  - ✅ Successfully imported")
            success_count += 1
            
        except Exception as e:
            print(f"  - ❌ Error: {str(e)}")
            error_count += 1
            continue
    
    conn.commit()
    cur.close()
    conn.close()
    
    print(f"✅ Climate suitability import complete!")
    print(f"   Success: {success_count}")
    print(f"   Errors: {error_count}")
    return True

def create_joined_view():
    """Create a view that joins nutrition and distribution data"""
    print("\n--- Creating Joined View ---")
    
    try:
        conn = psycopg2.connect(
            host="localhost",
            database="postgres",
            user="postgres"
        )
        cur = conn.cursor()
        
        # Create view for current climate suitability only (future can be added later)
        cur.execute("""
        CREATE VIEW species_complete AS
        SELECT 
            n.id as nutrition_id,
            n.property_input_id,
            n.genus_name,
            n.species_name,
            CONCAT(n.genus_name, ' ', n.species_name) as full_species_name,
            n.organ_name,
            n.values_data,
            n.type_info,
            n.unit_info,
            n.precision_val,
            n.uncertainty_val,
            n.data_source,
            n.accessed_date,
            n.comments,
            c.geometry as current_climate_suitability,
            c.metadata as climate_metadata,
            CASE 
                WHEN c.geometry IS NOT NULL THEN ST_Area(c.geometry::geography) / 1000000
                ELSE NULL 
            END as current_suitable_area_km2
        FROM species_nutrition n
        LEFT JOIN species_climate_suitability c ON n.genus_name = c.genus_name 
            AND n.species_name = c.species_name 
            AND c.climate_scenario = 'current';
        """)
        
        conn.commit()
        cur.close()
        conn.close()
        
        print("✅ Joined view created successfully")
        return True
        
    except Exception as e:
        print(f"❌ Failed to create view: {str(e)}")
        return False

def verify_import():
    """Verify the import and show summary statistics"""
    print("\n--- Verifying Import ---")
    
    try:
        conn = psycopg2.connect(
            host="localhost",
            database="postgres",
            user="postgres"
        )
        cur = conn.cursor()
        
        # Check nutrition data
        cur.execute("SELECT COUNT(*) FROM species_nutrition;")
        nutrition_count = cur.fetchone()[0]
        
        cur.execute("SELECT COUNT(DISTINCT CONCAT(genus_name, ' ', species_name)) FROM species_nutrition;")
        unique_species_nutrition = cur.fetchone()[0]
        
        # Check climate suitability data
        cur.execute("SELECT COUNT(*) FROM species_climate_suitability;")
        climate_count = cur.fetchone()[0]
        
        cur.execute("SELECT COUNT(DISTINCT CONCAT(genus_name, ' ', species_name)) FROM species_climate_suitability;")
        unique_species_climate = cur.fetchone()[0]
        
        # Check joined data (current climate suitability only)
        cur.execute("""
        SELECT 
            COUNT(*) as total_records,
            COUNT(current_climate_suitability) as has_climate_map,
            COUNT(DISTINCT full_species_name) as unique_species
        FROM species_complete;
        """)
        
        result = cur.fetchone()
        total_joined, has_climate, unique_joined = result
        
        cur.close()
        conn.close()
        
        print("📊 Import Summary:")
        print(f"   Nutrition records: {nutrition_count:,}")
        print(f"   Unique species (nutrition): {unique_species_nutrition}")
        print(f"   Climate suitability records: {climate_count}")
        print(f"   Unique species (climate): {unique_species_climate}")
        print(f"   Joined records: {total_joined:,}")
        print(f"   Records with climate maps: {has_climate:,}")
        print(f"   Unique species (joined): {unique_joined}")
        print(f"   Coverage: {(has_climate/total_joined*100):.1f}% of nutrition records have climate suitability maps")
        
        return True
        
    except Exception as e:
        print(f"❌ Verification failed: {str(e)}")
        return False

def main():
    """Main import process"""
    print("🌳 Starting Edible Trees Database Import Process")
    print("=" * 50)
    
    # Setup database
    if not setup_database():
        return
    
    # Import CSV data
    if not import_csv_data():
        return
    
    # Import GeoJSON data
    if not import_geojson_data():
        return
    
    # Create joined view
    if not create_joined_view():
        return
    
    # Verify import
    verify_import()
    
    print("\n" + "=" * 50)
    print("🎉 Import process complete!")
    print("\nNext steps:")
    print("1. Connect to database: docker compose exec pg psql -U postgres -d edible_trees_database")
    print("2. Test queries:")
    print("   SELECT * FROM species_complete WHERE genus_name = 'Annona' LIMIT 5;")
    print("   SELECT genus_name, species_name, COUNT(*) FROM species_complete GROUP BY genus_name, species_name;")
    print("3. Add future distributions later with: ALTER VIEW species_complete...")

if __name__ == "__main__":
    main()