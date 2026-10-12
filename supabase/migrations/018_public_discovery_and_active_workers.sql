-- ============================================================================
-- Migration 018: Public Discovery & Active/Available Workers RLS Policy Update
-- Allows customer guest / unauthenticated users to view active services and
-- discover available or active workers without encountering RLS permission blocks.
-- ============================================================================

-- 1. Enable Public Read on Services
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view active services" ON public.services;
DROP POLICY IF EXISTS "Authenticated users can view services" ON public.services;

CREATE POLICY "Public can view active services" 
ON public.services FOR SELECT 
USING (is_active = true);

-- 2. Enable Public Read on Available or Active Workers
ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view available workers" ON public.workers;
DROP POLICY IF EXISTS "Authenticated users can view workers" ON public.workers;

CREATE POLICY "Public can view available workers" 
ON public.workers FOR SELECT 
USING (
  is_available = true 
  OR worker_status = 'ACTIVE' 
  OR worker_status = 'PENDING_VERIFICATION' 
  OR (auth.uid() IS NOT NULL AND auth.uid() = id)
);

-- 3. Enable Public Read on Worker Skills for FairMatch Join
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'worker_skills') THEN
    ALTER TABLE public.worker_skills ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public can view worker skills" ON public.worker_skills;
    CREATE POLICY "Public can view worker skills" 
    ON public.worker_skills FOR SELECT 
    USING (true);
  END IF;
END $$;

-- 4. Enable Public Read on User Names & Avatars for Worker Profiles
DROP POLICY IF EXISTS "Public can view basic worker names" ON public.users;
CREATE POLICY "Public can view basic worker names"
ON public.users FOR SELECT
USING (
  role = 'WORKER' 
  OR (auth.uid() IS NOT NULL AND auth.uid() = id)
  OR public.auth_user_role() = 'ADMIN'
);
