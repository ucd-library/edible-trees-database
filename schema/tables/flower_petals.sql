-- create table for flower_petals
CREATE TABLE IF NOT EXISTS flower_petals (
  flower_petals_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flower_petals TEXT UNIQUE
);