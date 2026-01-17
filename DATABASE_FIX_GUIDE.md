# Database Schema Fix Guide

## ⚠️ Issues Detected

Your Prompit app is experiencing database schema mismatches. These errors are **separate from the mobile authentication fix** and need to be resolved by updating your Supabase database schema.

### Errors Found:
1. ✗ `folders.deleted` column does not exist
2. ✗ `folders.device_id` column missing
3. ✗ `folders.updated_at` column missing
4. ✗ Foreign key constraint errors (prompts referencing non-existent folders)

---

## ✅ Solution (Choose ONE)

### **Option 1: Run SQL Migration (Recommended)**

This is the easiest and safest solution.

#### Steps:

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard/project/[your-project-id]
   
2. **Navigate to SQL Editor**
   - Click "SQL Editor" in the left sidebar
   
3. **Run the Migration Script**
   - Click "+ New Query"
   - Copy the entire contents of `database_migration.sql`
   - Paste into the SQL editor
   - Click "Run" (or press Cmd/Ctrl + Enter)

4. **Verify Success**
   - You should see: "Success. No rows returned"
   - Check for any error messages

5. **Reload Your App**
   - Refresh your Prompit app
   - The errors should be gone! ✅

**File Location**: `/home/Mohit/code/Prompit/database_migration.sql`

---

### **Option 2: Manual Schema Updates (If you prefer)**

If you want to update the schema manually:

#### 1. Update `folders` table:

```sql
ALTER TABLE folders 
  ADD COLUMN IF NOT EXISTS device_id UUID,
  ADD COLUMN IF NOT EXISTS deleted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX idx_folders_deleted ON folders(deleted) WHERE deleted = false;
CREATE INDEX idx_folders_user_id ON folders(user_id);
CREATE INDEX idx_folders_device_id ON folders(device_id);
```

#### 2. Update `prompt_saves` table:

```sql
ALTER TABLE prompt_saves
  ADD COLUMN IF NOT EXISTS device_id UUID,
  ADD COLUMN IF NOT EXISTS deleted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_guest_data BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS client_mutation_id UUID,
  ADD COLUMN IF NOT EXISTS total_usage INTEGER DEFAULT 0;

-- Make folder_id nullable (optional - but recommended)
ALTER TABLE prompt_saves 
  ALTER COLUMN folder_id DROP NOT NULL;
```

#### 3. Fix existing data:

```sql
-- Set deleted to false for existing records
UPDATE folders SET deleted = false WHERE deleted IS NULL;
UPDATE prompt_saves SET deleted = false WHERE deleted IS NULL;

-- Remove invalid folder references
UPDATE prompt_saves 
SET folder_id = NULL 
WHERE folder_id IS NOT NULL 
  AND NOT EXISTS (
    SELECT 1 FROM folders WHERE folders.id = prompt_saves.folder_id
  );
```

---

## 🔧 App Improvements (Already Done)

I've already made your app more resilient to these schema issues:

### 1. **Graceful Folder Sync Fallback**
- ✅ If full schema fails, tries minimal schema
- ✅ Logs warnings instead of crashing
- ✅ App continues working locally even if cloud sync fails

### 2. **Foreign Key Validation**
- ✅ Checks if folder exists before syncing
- ✅ Automatically sets `folder_id` to `null` if folder missing
- ✅ Retries sync without folder reference on foreign key errors

### 3. **Better Error Messages**
- ✅ Clear console warnings about schema issues
- ✅ Guidance to run migration script
- ✅ Success confirmations when sync works

---

## 🧪 Testing After Migration

After running the migration:

1. **Clear Browser Console**
   - Open DevTools (F12)
   - Clear console (Cmd/Ctrl + K)

2. **Refresh the App**
   - Hard refresh: Cmd/Ctrl + Shift + R

3. **Check for Success**
   
   **You should see:**
   - ✅ "Folders synced to cloud successfully"
   - ✅ No 400 Bad Request errors
   - ✅ No foreign key constraint errors

   **You should NOT see:**
   - ❌ "column folders.deleted does not exist"
   - ❌ "foreign key constraint" errors
   - ❌ Multiple 409 Conflict errors

4. **Test Folder Creation**
   - Try creating a new folder
   - Save a prompt to that folder
   - Refresh the page
   - Folder and prompt should still be there

---

## 🎯 What Each Part of the Migration Does

### Tables Updated:

1. **`folders`** - Stores user's folder organization
   - Added: `device_id`, `deleted`, `updated_at`
   - Indexed for better performance
   
2. **`prompt_saves`** - Stores all prompts
   - Added: `device_id`, `deleted`, `is_guest_data`, `client_mutation_id`, `total_usage`
   - Made `folder_id` nullable (prompts don't need folders)
   - Indexed for better performance

3. **`profiles`** - User profile info
   - Created if missing
   - Added RLS policies for security

### Security (RLS Policies):

- ✅ Users can only see their own data
- ✅ Guest users can access data by device_id
- ✅ Prevents unauthorized access

---

## ❓ FAQ

### Q: Will this delete my data?
**A:** No! The migration only **adds** columns and fixes data. It does not delete anything.

### Q: What if the migration fails?
**A:** The migration uses `IF NOT EXISTS` and `IF EXISTS`, so it's safe to run multiple times. If a step fails, check the error message and skip that step.

### Q: Can I run the migration in parts?
**A:** Yes! Each section (marked with comments like `-- 1.`, `-- 2.`, etc.) can be run separately.

### Q: What if I already have some of these columns?
**A:** The migration checks before adding (`ADD COLUMN IF NOT EXISTS`), so it won't cause errors.

### Q: Do I need to run this on my phone?
**A:** No! Run it once in Supabase dashboard. It affects the entire database, so all devices (desktop, mobile, etc.) will benefit.

---

## 🚨 If You Still See Errors

### After Migration, if errors persist:

1. **Check Supabase Health**
   - Go to Supabase Dashboard → Settings → Database
   - Check if there are any ongoing migrations
   - Wait for them to complete

2. **Verify Columns Were Added**
   ```sql
   -- Run this in SQL Editor to check:
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'folders';
   ```

3. **Check RLS Policies**
   - Go to: Table Editor → folders → Policies
   - Ensure you have policies for SELECT, INSERT, UPDATE

4. **Clear Local Storage & Sync Queue**
   - Open DevTools → Application → Local Storage
   - Clear `syncQueue` key
   - Refresh the app

5. **Still broken?**
   - Export your data: Settings → Export JSON
   - Clear local storage completely
   - Reload app
   - Import your data back

---

## 📝 Summary

**What to do:**
1. Run `database_migration.sql` in Supabase SQL Editor
2. Refresh your app
3. Errors should be gone! ✅

**Timeline:** 
- Migration takes: ~30 seconds
- Complete fix: ~2 minutes total

**Files Created:**
- `/home/Mohit/code/Prompit/database_migration.sql` - Full migration script
- `/home/Mohit/code/Prompit/app.js` - Already updated with resilient error handling

---

**Status**: 🔧 Ready to apply migration

**Date**: 2026-01-17
