-- create table for flower_tube
CREATE TABLE IF NOT EXISTS flower_tube (
  flower_tube_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flower_tube TEXT UNIQUE
);