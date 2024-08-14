-- create table for flower_direction
CREATE TABLE IF NOT EXISTS flower_direction (
  flower_direction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flower_direction TEXT UNIQUE
);