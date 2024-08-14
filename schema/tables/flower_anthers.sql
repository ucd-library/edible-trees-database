-- create table for flower_anthers
CREATE TABLE IF NOT EXISTS flower_anthers (
  flower_anthers_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flower_anthers TEXT UNIQUE
);