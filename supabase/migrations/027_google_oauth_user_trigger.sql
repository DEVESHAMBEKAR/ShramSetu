-- Migration 027: Automatic Google OAuth & Auth User Sync to public.users
-- Ensures all accounts created via Google OAuth, Phone, or Email are automatically
-- provisioned into public.users with their correct role, full name, and avatar.

-- 1. Create or replace the handle_new_user trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_role TEXT;
  v_name TEXT;
  v_avatar TEXT;
BEGIN
  -- Determine role: check user metadata, app metadata, or default to CUSTOMER
  v_role := COALESCE(
    NEW.raw_user_meta_data->>'role',
    NEW.raw_app_meta_data->>'role',
    'CUSTOMER'
  );
  v_role := UPPER(TRIM(v_role));

  -- Prevent accidental ADMIN assignment for arbitrary third-party OAuth logins
  IF v_role = 'ADMIN' AND NOT (
    LOWER(NEW.email) = 'admin@shramsetu.in' OR 
    LOWER(NEW.email) LIKE '%admin@%'
  ) THEN
    v_role := 'CUSTOMER';
  END IF;

  -- Determine full name
  v_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1),
    'User'
  );

  -- Determine avatar URL (Google picture)
  v_avatar := COALESCE(
    NEW.raw_user_meta_data->>'avatar_url',
    NEW.raw_user_meta_data->>'picture'
  );

  -- Insert or update public.users
  INSERT INTO public.users (
    id,
    email,
    phone,
    role,
    full_name,
    avatar_url,
    is_active,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    NULLIF(TRIM(COALESCE(NEW.phone, '')), ''),
    v_role,
    v_name,
    v_avatar,
    true,
    COALESCE(NEW.created_at, NOW()),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    phone = COALESCE(EXCLUDED.phone, public.users.phone),
    avatar_url = COALESCE(EXCLUDED.avatar_url, public.users.avatar_url),
    full_name = CASE 
      WHEN public.users.full_name IS NULL OR public.users.full_name = '' OR public.users.full_name LIKE 'User%' 
      THEN EXCLUDED.full_name 
      ELSE public.users.full_name 
    END,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Attach trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Ensure RLS policies allow authenticated users to insert/update their own profile
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
CREATE POLICY "Users can insert their own profile" 
  ON public.users FOR INSERT 
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
CREATE POLICY "Users can update their own profile" 
  ON public.users FOR UPDATE 
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
CREATE POLICY "Users can view their own profile" 
  ON public.users FOR SELECT 
  USING (auth.uid() = id);

-- 4. One-time backfill: Sync ALL existing auth.users (including the new Google accounts) into public.users
INSERT INTO public.users (
  id,
  email,
  phone,
  role,
  full_name,
  avatar_url,
  is_active,
  created_at,
  updated_at
)
SELECT 
  u.id,
  u.email,
  NULLIF(TRIM(COALESCE(u.phone, '')), ''),
  CASE 
    WHEN UPPER(COALESCE(u.raw_user_meta_data->>'role', u.raw_app_meta_data->>'role', 'CUSTOMER')) = 'ADMIN' 
         AND NOT (LOWER(u.email) = 'admin@shramsetu.in' OR LOWER(u.email) LIKE '%admin@%')
    THEN 'CUSTOMER'
    ELSE UPPER(COALESCE(u.raw_user_meta_data->>'role', u.raw_app_meta_data->>'role', 'CUSTOMER'))
  END,
  COALESCE(
    u.raw_user_meta_data->>'full_name',
    u.raw_user_meta_data->>'name',
    split_part(u.email, '@', 1),
    'User'
  ),
  COALESCE(
    u.raw_user_meta_data->>'avatar_url',
    u.raw_user_meta_data->>'picture'
  ),
  true,
  COALESCE(u.created_at, NOW()),
  NOW()
FROM auth.users u
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  phone = COALESCE(EXCLUDED.phone, public.users.phone),
  avatar_url = COALESCE(EXCLUDED.avatar_url, public.users.avatar_url),
  full_name = CASE 
    WHEN public.users.full_name IS NULL OR public.users.full_name = '' OR public.users.full_name LIKE 'User%' 
    THEN EXCLUDED.full_name 
    ELSE public.users.full_name 
  END,
  role = CASE
    WHEN public.users.role = 'ADMIN' AND NOT (LOWER(EXCLUDED.email) = 'admin@shramsetu.in' OR LOWER(EXCLUDED.email) LIKE '%admin@%')
    THEN EXCLUDED.role
    ELSE public.users.role
  END,
  updated_at = NOW();
