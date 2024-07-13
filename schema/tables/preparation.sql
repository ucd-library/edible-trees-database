CREATE TABLE IF NOT EXISTS preparation  (
  preparation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  preparation TEXT UNIQUE
);