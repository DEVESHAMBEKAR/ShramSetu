-- ============================================================================
-- Migration 028: Repair Booking & Verification RLS Policies
-- 1. Allows Workers to view customer basic profiles (full_name, phone) for assigned bookings.
-- 2. Allows all admin tiers (ADMIN, SUPER_ADMIN, FEDERATION_ADMIN) to view all users.
-- 3. Allows all admin tiers to insert and view worker_verification_history.
-- 4. Allows all admin tiers to insert worker_verification_documents.
-- 5. Ensures workers and admins can view delivery addresses linked to bookings.
-- ============================================================================

-- 1. Users Table: Workers can view customer profiles for bookings assigned to them
DROP POLICY IF EXISTS "Workers can view customers of assigned bookings" ON public.users;
CREATE POLICY "Workers can view customers of assigned bookings"
ON public.users FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.bookings
    WHERE bookings.customer_id = users.id
      AND bookings.worker_id = auth.uid()
  )
);

-- Ensure all admin tiers can view user profiles
DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
CREATE POLICY "Admins can view all users"
ON public.users FOR SELECT
USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 2. Worker Verification History: Allow all admin tiers to insert and view
DROP POLICY IF EXISTS "Admins can view verification history" ON public.worker_verification_history;
CREATE POLICY "Admins can view verification history"
ON public.worker_verification_history FOR SELECT
USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can insert verification history" ON public.worker_verification_history;
CREATE POLICY "Admins can insert verification history"
ON public.worker_verification_history FOR INSERT
WITH CHECK (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 3. Worker Verification Documents: Allow all admin tiers to insert missing document records
DROP POLICY IF EXISTS "Admins can insert verification documents" ON public.worker_verification_documents;
CREATE POLICY "Admins can insert verification documents"
ON public.worker_verification_documents FOR INSERT
WITH CHECK (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 4. Addresses: Ensure assigned workers and admins can read addresses for bookings
DROP POLICY IF EXISTS "Workers can view customer address for their bookings" ON public.addresses;
CREATE POLICY "Workers can view customer address for their bookings"
ON public.addresses FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.bookings
    WHERE bookings.address_id = addresses.id
      AND bookings.worker_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admins can view all addresses" ON public.addresses;
CREATE POLICY "Admins can view all addresses"
ON public.addresses FOR SELECT
USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));
