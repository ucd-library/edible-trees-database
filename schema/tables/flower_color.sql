-- create table for flower_color
CREATE TABLE IF NOT EXISTS flower_color (
  flower_color_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flower_color TEXT UNIQUE
);