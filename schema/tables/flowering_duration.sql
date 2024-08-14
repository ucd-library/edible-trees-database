-- create table for flowering_duration
CREATE TABLE IF NOT EXISTS flowering_duration (
  flowering_duration_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flowering_duration TEXT UNIQUE
);