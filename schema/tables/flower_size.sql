-- create table for flower_size
CREATE TABLE IF NOT EXISTS flower_size (
  flower_size_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flower_size TEXT UNIQUE
);