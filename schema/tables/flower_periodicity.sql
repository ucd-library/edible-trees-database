-- create table for flower_periodicity
CREATE TABLE IF NOT EXISTS flower_periodicity (
  flower_periodicity_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flower_periodicity TEXT UNIQUE
);