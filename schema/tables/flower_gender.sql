-- create table for flower_gender
CREATE TABLE IF NOT EXISTS flower_gender (
  flower_gender_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flower_gender TEXT UNIQUE
);