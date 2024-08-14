-- create table for flower_symmetry
CREATE TABLE IF NOT EXISTS flower_symmetry (
  flower_symmetry_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flower_symmetry TEXT UNIQUE
);