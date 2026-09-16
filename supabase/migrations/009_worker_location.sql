-- ============================================================================
-- Migration 009: Worker Location Columns
-- Phase 18 — Location + Google Maps / GPS Infrastructure
-- ============================================================================

-- 1. Add coordinates and timestamp to public.workers
-- Existing rows are preserved with NULL coordinates (backward compatible).
ALTER TABLE public.workers
  ADD COLUMN IF NOT EXISTS latitude NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMP WITH TIME ZONE;

-- 2. Index for spatial/distance queries if needed in future
CREATE INDEX IF NOT EXISTS idx_workers_location 
  ON public.workers(latitude, longitude) 
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- 3. Security / RLS Note:
-- Existing policy in 002_rls_policies.sql:
--   "Workers can update own worker profile" ON public.workers FOR UPDATE USING (auth.uid() = id);
--   "Authenticated users can view workers" ON public.workers FOR SELECT USING (auth.uid() IS NOT NULL AND worker_status = 'ACTIVE');
--   "Admins can manage workers" ON public.workers FOR ALL USING (auth_user_role() = 'ADMIN');
-- These policies remain enforced and allow workers to update their own location.
