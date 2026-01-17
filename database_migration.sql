-- ============================================
-- Prompit Database Schema Migration
-- ============================================
-- Run this in your Supabase SQL Editor to fix schema issues
-- Compatible with PostgreSQL 12+ (Supabase)
-- Date: 2026-01-17

-- ============================================
-- 1. Update FOLDERS table schema
-- ============================================

-- Add missing columns to folders table if they don't exist
ALTER TABLE folders 
  ADD COLUMN IF NOT EXISTS device_id UUID,
  ADD COLUMN IF NOT EXISTS deleted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_folders_deleted ON folders(deleted) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_folders_user_id ON folders(user_id);
CREATE INDEX IF NOT EXISTS idx_folders_device_id ON folders(device_id);

-- Update existing rows to have default values
UPDATE folders 
SET deleted = false 
WHERE deleted IS NULL;

UPDATE folders 
SET updated_at = created_at 
WHERE updated_at IS NULL;

COMMENT ON COLUMN folders.device_id IS 'Device identifier for guest/offline sync';
COMMENT ON COLUMN folders.deleted IS 'Soft delete flag - true means folder is deleted';
COMMENT ON COLUMN folders.updated_at IS 'Timestamp of last update';

-- ============================================
-- 2. Update PROMPT_SAVES table schema
-- ============================================

-- Ensure prompt_saves has all necessary columns
ALTER TABLE prompt_saves
  ADD COLUMN IF NOT EXISTS device_id UUID,
  ADD COLUMN IF NOT EXISTS deleted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_guest_data BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS client_mutation_id UUID,
  ADD COLUMN IF NOT EXISTS total_usage INTEGER DEFAULT 0;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_prompt_saves_deleted ON prompt_saves(deleted) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_prompt_saves_device_id ON prompt_saves(device_id);
CREATE INDEX IF NOT EXISTS idx_prompt_saves_client_mutation_id ON prompt_saves(client_mutation_id);
CREATE INDEX IF NOT EXISTS idx_prompt_saves_folder_id ON prompt_saves(folder_id);

-- Update existing rows
UPDATE prompt_saves 
SET deleted = false 
WHERE deleted IS NULL;

UPDATE prompt_saves 
SET is_guest_data = false 
WHERE is_guest_data IS NULL;

UPDATE prompt_saves 
SET total_usage = 0 
WHERE total_usage IS NULL;

-- ============================================
-- 3. Fix Foreign Key Constraint
-- ============================================

-- Make folder_id nullable (prompts don't have to be in folders)
DO $$ 
BEGIN
  ALTER TABLE prompt_saves ALTER COLUMN folder_id DROP NOT NULL;
EXCEPTION
  WHEN undefined_column THEN NULL;
  WHEN others THEN NULL;
END $$;

-- Update any prompts with invalid folder_id to NULL
UPDATE prompt_saves 
SET folder_id = NULL 
WHERE folder_id IS NOT NULL 
  AND NOT EXISTS (
    SELECT 1 FROM folders WHERE folders.id = prompt_saves.folder_id
  );

-- ============================================
-- 4. Create or update PROFILES table
-- ============================================

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  last_login TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_profiles_id ON profiles(id);

-- Enable RLS (Row Level Security)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Drop and recreate policies for profiles (DROP doesn't error if not exists)
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- Create policies
CREATE POLICY "Users can view own profile" 
  ON profiles FOR SELECT 
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" 
  ON profiles FOR UPDATE 
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" 
  ON profiles FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- ============================================
-- 5. Update RLS Policies for folders
-- ============================================

-- Enable RLS if not already enabled
ALTER TABLE folders ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (safe - no error if not exists)
DROP POLICY IF EXISTS "Users can view own folders" ON folders;
DROP POLICY IF EXISTS "Users can insert own folders" ON folders;
DROP POLICY IF EXISTS "Users can update own folders" ON folders;
DROP POLICY IF EXISTS "Users can delete own folders" ON folders;
DROP POLICY IF EXISTS "Guest users can view by device_id" ON folders;

-- Create new policies
CREATE POLICY "Users can view own folders" 
  ON folders FOR SELECT 
  USING (
    auth.uid() = user_id 
    OR (user_id IS NULL AND device_id IS NOT NULL)
  );

CREATE POLICY "Users can insert own folders" 
  ON folders FOR INSERT 
  WITH CHECK (
    auth.uid() = user_id 
    OR user_id IS NULL
  );

CREATE POLICY "Users can update own folders" 
  ON folders FOR UPDATE 
  USING (
    auth.uid() = user_id 
    OR (user_id IS NULL AND device_id IS NOT NULL)
  );

CREATE POLICY "Users can delete own folders" 
  ON folders FOR DELETE 
  USING (
    auth.uid() = user_id 
    OR (user_id IS NULL AND device_id IS NOT NULL)
  );

-- ============================================
-- 6. Update RLS Policies for prompt_saves
-- ============================================

-- Enable RLS if not already enabled
ALTER TABLE prompt_saves ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own prompts" ON prompt_saves;
DROP POLICY IF EXISTS "Users can insert own prompts" ON prompt_saves;
DROP POLICY IF EXISTS "Users can update own prompts" ON prompt_saves;
DROP POLICY IF EXISTS "Users can delete own prompts" ON prompt_saves;

-- Create new policies
CREATE POLICY "Users can view own prompts" 
  ON prompt_saves FOR SELECT 
  USING (
    auth.uid() = user_id 
    OR (user_id IS NULL AND device_id IS NOT NULL)
  );

CREATE POLICY "Users can insert own prompts" 
  ON prompt_saves FOR INSERT 
  WITH CHECK (
    auth.uid() = user_id 
    OR user_id IS NULL
  );

CREATE POLICY "Users can update own prompts" 
  ON prompt_saves FOR UPDATE 
  USING (
    auth.uid() = user_id 
    OR (user_id IS NULL AND device_id IS NOT NULL)
  );

CREATE POLICY "Users can delete own prompts" 
  ON prompt_saves FOR DELETE 
  USING (
    auth.uid() = user_id 
    OR (user_id IS NULL AND device_id IS NOT NULL)
  );

-- ============================================
-- 7. Success Message
-- ============================================

DO $$ 
BEGIN 
  RAISE NOTICE '✅ Migration completed successfully!'; 
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '1. Refresh your Prompit app';
  RAISE NOTICE '2. Check console for "Folders synced to cloud successfully"';
  RAISE NOTICE '3. Verify no 400 errors appear';
END $$;

-- ============================================
-- END OF MIGRATION
-- ============================================
