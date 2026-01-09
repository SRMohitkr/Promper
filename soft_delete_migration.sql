-- 1) Schema change (DB)
ALTER TABLE public.prompt_saves
  ADD COLUMN IF NOT EXISTS deleted boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_prompt_saves_not_deleted 
ON public.prompt_saves (deleted) WHERE deleted = false;

-- 2) RLS & Policies (DB security)
-- Optimizing RLS Policies for Performance and adding soft-delete enforcement

-- Fix: device_metadata
DROP POLICY IF EXISTS "Devices can manage metadata" ON "public"."device_metadata";
CREATE POLICY "Devices can manage metadata" ON "public"."device_metadata"
AS PERMISSIVE FOR ALL
TO public
USING (
  device_id = (SELECT current_setting('request.headers', true)::json->>'x-device-id')
)
WITH CHECK (
  device_id = (SELECT current_setting('request.headers', true)::json->>'x-device-id')
);

-- Fix: prompt_saves
DROP POLICY IF EXISTS "Users and Devices can manage their own prompts" ON "public"."prompt_saves";
DROP POLICY IF EXISTS "Users can view own prompts" ON "public"."prompt_saves";
DROP POLICY IF EXISTS "Prevent selecting deleted" ON "public"."prompt_saves";

CREATE POLICY "Users and Devices can manage their own prompts" ON "public"."prompt_saves"
AS PERMISSIVE FOR ALL
TO public
USING (
  (deleted = false) AND (
    (user_id = (SELECT auth.uid())) OR 
    (device_id = (SELECT current_setting('request.headers', true)::json->>'x-device-id'))
  )
)
WITH CHECK (
  (user_id = (SELECT auth.uid())) OR 
  (device_id = (SELECT current_setting('request.headers', true)::json->>'x-device-id'))
);

-- Fix: folders (View)
DROP POLICY IF EXISTS "Users and Devices can view own folders" ON "public"."folders";
CREATE POLICY "Users and Devices can view own folders" ON "public"."folders"
AS PERMISSIVE FOR SELECT
TO public
USING (
  (user_id = (SELECT auth.uid())) OR 
  (device_id = (SELECT current_setting('request.headers', true)::json->>'x-device-id'))
);

-- Note: Folding soft delete into folders is not requested, but RLS performance fixes are applied.
