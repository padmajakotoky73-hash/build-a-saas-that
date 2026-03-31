```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pg_crypto for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table (maps to Supabase auth.users)
CREATE TABLE IF NOT EXISTS users (
  id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  email TEXT NOT NULL,
  full_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  PRIMARY KEY (id)
);

-- Enable RLS on users
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- User RLS policies
CREATE POLICY "Users can view their own data" 
ON users FOR SELECT 
USING (auth.uid() = id);

CREATE POLICY "Users can update their own data"
ON users FOR UPDATE
USING (auth.uid() = id);

-- NDA Templates table
CREATE TABLE IF NOT EXISTS nda_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  is_public BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable RLS on nda_templates
ALTER TABLE nda_templates ENABLE ROW LEVEL SECURITY;

-- NDA Templates RLS policies
CREATE POLICY "Users can view their own templates"
ON nda_templates FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can view public templates"
ON nda_templates FOR SELECT
USING (is_public = TRUE);

CREATE POLICY "Users can create templates"
ON nda_templates FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own templates"
ON nda_templates FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own templates"
ON nda_templates FOR DELETE
USING (auth.uid() = user_id);

-- Generated NDAs table
CREATE TABLE IF NOT EXISTS generated_ndas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  template_id UUID REFERENCES nda_templates(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  recipient_email TEXT NOT NULL,
  is_signed BOOLEAN DEFAULT FALSE,
  signed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable RLS on generated_ndas
ALTER TABLE generated_ndas ENABLE ROW LEVEL SECURITY;

-- Generated NDAs RLS policies
CREATE POLICY "Users can view their own generated NDAs"
ON generated_ndas FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can create NDAs"
ON generated_ndas FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own NDAs"
ON generated_ndas FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own NDAs"
ON generated_ndas FOR DELETE
USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX idx_nda_templates_user_id ON nda_templates(user_id);
CREATE INDEX idx_generated_ndas_user_id ON generated_ndas(user_id);
CREATE INDEX idx_generated_ndas_template_id ON generated_ndas(template_id);
CREATE INDEX idx_generated_ndas_recipient_email ON generated_ndas(recipient_email);

-- Seed data (public templates)
INSERT INTO nda_templates (id, user_id, title, content, is_public, created_at, updated_at)
VALUES 
  (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000000', -- system user
    'Standard Mutual NDA',
    'This Mutual Non-Disclosure Agreement (the "Agreement") is made and entered into as of [DATE] by and between [PARTY A NAME], a [STATE] [ENTITY TYPE] with its principal office at [ADDRESS] ("Party A"), and [PARTY B NAME], a [STATE] [ENTITY TYPE] with its principal office at [ADDRESS] ("Party B").',
    TRUE,
    NOW(),
    NOW()
  ),
  (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000000', -- system user
    'One-Way NDA',
    'This Non-Disclosure Agreement (the "Agreement") is made and entered into as of [DATE] by and between [DISCLOSING PARTY NAME], a [STATE] [ENTITY TYPE] with its principal office at [ADDRESS] ("Disclosing Party"), and [RECEIVING PARTY NAME], a [STATE] [ENTITY TYPE] with its principal office at [ADDRESS] ("Receiving Party").',
    TRUE,
    NOW(),
    NOW()
  );

-- Create a trigger to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the trigger to all tables
CREATE TRIGGER update_users_modtime
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_nda_templates_modtime
BEFORE UPDATE ON nda_templates
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_generated_ndas_modtime
BEFORE UPDATE ON generated_ndas
FOR EACH ROW EXECUTE FUNCTION update_modified_column();
```