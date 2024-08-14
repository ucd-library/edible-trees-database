-- create table for flower_nector
CREATE TABLE IF NOT EXISTS flower_nector (
  flower_nector_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flower_nector TEXT UNIQUE
);