
DO $$ 
BEGIN
  CREATE TYPE qa_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION
  WHEN duplicate_object THEN
    -- Handle the exception here
    RAISE NOTICE 'The type qa_status already exists.';
END $$;