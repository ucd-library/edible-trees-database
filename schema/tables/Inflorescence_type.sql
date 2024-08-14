-- create table for Inflorescence_type
CREATE TABLE IF NOT EXISTS Inflorescence_type (
  Inflorescence_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  Inflorescence_type TEXT UNIQUE
);