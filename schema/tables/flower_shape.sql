-- create table for flower_shape
CREATE TABLE IF NOT EXISTS flower_shape (
  flower_shape_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flower_shape TEXT UNIQUE
);