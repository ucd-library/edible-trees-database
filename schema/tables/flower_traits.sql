-- create table for flower_traits
CREATE TABLE IF NOT EXISTS flower_traits (
  flower_traits UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  species_id UUID NOT NULL REFERENCES species(species_id),
  flower_anthers UUID  REFERENCES flower_anthers(flower_anthers_id),
  flower_color UUID  REFERENCES flower_color(flower_color_id),
  flower_direction UUID  REFERENCES flower_direction(flower_direction_id),
  flower_gender UUID  REFERENCES flower_gender(flower_gender_id),
  flower_nector UUID  REFERENCES flower_nector (flower_nector_id),
  flower_periodicity UUID  REFERENCES flower_periodicity (flower_periodicity_id),
  flower_petals UUID  REFERENCES flower_petals (flower_petals_id),
  flower_shape UUID  REFERENCES flower_shape (flower_shape_id),
  flower_size UUID  REFERENCES flower_size (flower_size_id),
  flower_symmetry UUID  REFERENCES flower_symmetry (flower_symmetry_id),
  flower_tube UUID  REFERENCES flower_tube (flower_tube_id),
  flowering_duration UUID  REFERENCES flowering_duration (flowering_duration_id),
  inflorescence_type UUID  REFERENCES inflorescence_type (inflorescence_type_id),
);