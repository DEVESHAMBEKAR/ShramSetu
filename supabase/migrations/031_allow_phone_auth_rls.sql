-- ============================================================================
-- Migration 031: Phone Auth RLS & Cross-Provider Profile Persistence
-- 1. Uncouples public.users from auth.users hard FK so Firebase & Phone users persist.
-- 2. Backfills all existing auth.users into public.users with their names and phones.
-- 3. Opens RLS permissions for public/anon & authenticated roles so phone auth clients
--    can read & update profiles, save addresses, and manage bookings seamlessly.
-- ============================================================================

-- 1. Remove strict FK to auth.users if present, allowing external auth uids
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'users_id_fkey' AND table_name = 'users'
  ) THEN
    ALTER TABLE public.users DROP CONSTRAINT users_id_fkey;
  END IF;
END $$;

-- 2. Backfill existing auth.users (including phone accounts) into public.users
INSERT INTO public.users (
  id,
  full_name,
  phone,
  email,
  role,
  avatar_url,
  is_active,
  created_at,
  updated_at
)
SELECT 
  u.id,
  COALESCE(
    NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(u.raw_user_meta_data->>'name'), ''),
    split_part(u.email, '@', 1),
    'User ' || right(COALESCE(u.phone, '0000'), 4)
  ) AS full_name,
  COALESCE(NULLIF(TRIM(u.phone), ''), u.raw_user_meta_data->>'phone') AS phone,
  u.email,
  COALESCE(
    NULLIF(TRIM(u.raw_user_meta_data->>'role'), ''),
    NULLIF(TRIM(u.raw_app_meta_data->>'role'), ''),
    'CUSTOMER'
  ) AS role,
  COALESCE(
    u.raw_user_meta_data->>'avatar_url',
    u.raw_user_meta_data->>'picture'
  ) AS avatar_url,
  true,
  COALESCE(u.created_at, NOW()),
  NOW()
FROM auth.users u
ON CONFLICT (id) DO UPDATE SET
  full_name = CASE 
    WHEN public.users.full_name IS NULL OR public.users.full_name = '' OR public.users.full_name LIKE 'User%' 
    THEN EXCLUDED.full_name 
    ELSE public.users.full_name 
  END,
  phone = COALESCE(public.users.phone, EXCLUDED.phone),
  email = COALESCE(public.users.email, EXCLUDED.email),
  updated_at = NOW();

-- 3. Enable RLS on public.users and grant full read/write for phone auth client
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow read users" ON public.users;
DROP POLICY IF EXISTS "Public can view basic worker names" ON public.users;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
CREATE POLICY "Allow read users" ON public.users 
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert users" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
CREATE POLICY "Allow insert users" ON public.users 
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update users" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
CREATE POLICY "Allow update users" ON public.users 
  FOR UPDATE USING (true) WITH CHECK (true);

-- 4. Enable RLS on public.addresses and allow users & customers to manage addresses
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own addresses" ON public.addresses;
DROP POLICY IF EXISTS "Allow manage addresses" ON public.addresses;
DROP POLICY IF EXISTS "Workers can view customer address for their bookings" ON public.addresses;
DROP POLICY IF EXISTS "Admins can view all addresses" ON public.addresses;

CREATE POLICY "Allow manage addresses" ON public.addresses 
  FOR ALL USING (true) WITH CHECK (true);

-- 5. Enable RLS on workers & verification tables
ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow manage workers" ON public.workers;
DROP POLICY IF EXISTS "Public can view available workers" ON public.workers;
DROP POLICY IF EXISTS "Authenticated users can view workers" ON public.workers;
DROP POLICY IF EXISTS "Workers can view own worker profile" ON public.workers;
DROP POLICY IF EXISTS "Workers can update own worker profile" ON public.workers;
CREATE POLICY "Allow manage workers" ON public.workers 
  FOR ALL USING (true) WITH CHECK (true);

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'worker_verification') THEN
    ALTER TABLE public.worker_verification ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Allow manage worker verification" ON public.worker_verification;
    CREATE POLICY "Allow manage worker verification" ON public.worker_verification 
      FOR ALL USING (true) WITH CHECK (true);
  END IF;

  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'worker_verification_documents') THEN
    ALTER TABLE public.worker_verification_documents ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Allow manage worker verification documents" ON public.worker_verification_documents;
    CREATE POLICY "Allow manage worker verification documents" ON public.worker_verification_documents 
      FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 6. Enable RLS on bookings, payments, and reviews
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow manage bookings" ON public.bookings;
DROP POLICY IF EXISTS "Customers can view their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Customers can create bookings" ON public.bookings;
CREATE POLICY "Allow manage bookings" ON public.bookings 
  FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow manage payments" ON public.payments;
CREATE POLICY "Allow manage payments" ON public.payments 
  FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow manage reviews" ON public.reviews;
CREATE POLICY "Allow manage reviews" ON public.reviews 
  FOR ALL USING (true) WITH CHECK (true);

-- 7. Add performance indexes for phone and user Lookups
CREATE INDEX IF NOT EXISTS idx_users_phone ON public.users(phone);
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON public.addresses(user_id);
