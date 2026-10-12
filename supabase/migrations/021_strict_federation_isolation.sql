-- ============================================================================
-- Migration 021: Strict Federation Isolation and Super Admin Multi-Location Oversight
-- Enforces row-level isolation so that:
-- 1. Federation Admins (FEDERATION_ADMIN) can ONLY access workers and customers
--    belonging to their assigned cooperative federation(s).
-- 2. Super Admins (SUPER_ADMIN) and legacy ADMIN have unrestricted national
--    access across all federations, states, districts, and locations.
-- ============================================================================

-- 0. Ensure worker columns exist (idempotent across existing schemas)
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS dob DATE;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS trade TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS primary_skill TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS skill_level TEXT DEFAULT 'Intermediate';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS district TEXT DEFAULT 'Pune';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS pincode TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS federation_name TEXT DEFAULT 'Pune District Labour Cooperative Federation';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS membership_id TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS verification_remarks TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.users(id);
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS federation_ref_id UUID REFERENCES public.federations(id) ON DELETE SET NULL;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'Maharashtra';

-- 1. Helper function: Returns array of federation IDs authorized for current caller
CREATE OR REPLACE FUNCTION public.get_admin_federation_ids()
RETURNS UUID[]
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
    SELECT COALESCE(array_agg(federation_id), '{}')
    FROM public.admin_federation_scope
    WHERE user_id = auth.uid() AND is_active = true;
$$;

-- 2. Performance Indexes for Federation & Geographic Multi-Location Queries
CREATE INDEX IF NOT EXISTS idx_workers_federation_ref_id ON public.workers(federation_ref_id);
CREATE INDEX IF NOT EXISTS idx_workers_district ON public.workers(district);
CREATE INDEX IF NOT EXISTS idx_workers_state ON public.workers(state);
CREATE INDEX IF NOT EXISTS idx_workers_created_at ON public.workers(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_addresses_district ON public.addresses(district);
CREATE INDEX IF NOT EXISTS idx_addresses_city ON public.addresses(city);
CREATE INDEX IF NOT EXISTS idx_addresses_state ON public.addresses(state);

-- 3. Strict Federation Isolation on Workers Table
DROP POLICY IF EXISTS "Admins can manage workers" ON public.workers;
DROP POLICY IF EXISTS "Federation admins manage scoped workers" ON public.workers;

-- Super Admins and global Admins can manage all workers
CREATE POLICY "Super admins can manage all workers" ON public.workers
    FOR ALL USING (public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN'));

-- Federation Admins can ONLY select and manage workers within their authorized federation
CREATE POLICY "Federation admins manage scoped workers" ON public.workers
    FOR ALL USING (
        public.auth_user_role() = 'FEDERATION_ADMIN'
        AND federation_ref_id = ANY(public.get_admin_federation_ids())
    );

-- Workers can view and manage their own profile
DROP POLICY IF EXISTS "Workers can manage own profile" ON public.workers;
CREATE POLICY "Workers can manage own profile" ON public.workers
    FOR ALL USING (auth.uid() = id);

-- Public / Customers can discover active verified workers
DROP POLICY IF EXISTS "Anyone authenticated can view active workers" ON public.workers;
CREATE POLICY "Anyone authenticated can view active workers" ON public.workers
    FOR SELECT USING (
        worker_status = 'ACTIVE'
        OR auth.uid() = id
        OR public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN', 'FEDERATION_ADMIN')
    );

-- 4. Strict Isolation on Worker Verification
DROP POLICY IF EXISTS "Admins can manage verifications" ON public.worker_verification;

CREATE POLICY "Super admins can manage all verifications" ON public.worker_verification
    FOR ALL USING (public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN'));

CREATE POLICY "Federation admins manage scoped verifications" ON public.worker_verification
    FOR ALL USING (
        public.auth_user_role() = 'FEDERATION_ADMIN'
        AND worker_id IN (
            SELECT id FROM public.workers
            WHERE federation_ref_id = ANY(public.get_admin_federation_ids())
        )
    );

-- 5. Strict Isolation on Worker Verification Documents
DROP POLICY IF EXISTS "Admins can view all verification documents" ON public.worker_verification_documents;
DROP POLICY IF EXISTS "Admins can update verification documents" ON public.worker_verification_documents;

CREATE POLICY "Super admins can manage all verification documents" ON public.worker_verification_documents
    FOR ALL USING (public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN'));

CREATE POLICY "Federation admins manage scoped verification documents" ON public.worker_verification_documents
    FOR ALL USING (
        public.auth_user_role() = 'FEDERATION_ADMIN'
        AND worker_id IN (
            SELECT id FROM public.workers
            WHERE federation_ref_id = ANY(public.get_admin_federation_ids())
        )
    );

-- 6. Strict Verification RPC function: Enforces federation boundary
CREATE OR REPLACE FUNCTION public.admin_verify_worker_scoped(
    p_worker_id UUID,
    p_action TEXT,
    p_remarks TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_actor_role TEXT;
    v_caller_id UUID;
    v_worker_fed_id UUID;
    v_auth_feds UUID[];
    v_new_status TEXT;
BEGIN
    v_caller_id := auth.uid();
    SELECT role INTO v_actor_role FROM public.users WHERE id = v_caller_id;

    IF v_actor_role NOT IN ('SUPER_ADMIN', 'ADMIN', 'FEDERATION_ADMIN') THEN
        RAISE EXCEPTION 'Access Denied: Caller is not an authorized administrator';
    END IF;

    -- For FEDERATION_ADMIN: check worker belongs to authorized federation
    IF v_actor_role = 'FEDERATION_ADMIN' THEN
        SELECT federation_ref_id INTO v_worker_fed_id FROM public.workers WHERE id = p_worker_id;
        v_auth_feds := public.get_admin_federation_ids();

        IF v_worker_fed_id IS NULL OR NOT (v_worker_fed_id = ANY(v_auth_feds)) THEN
            RAISE EXCEPTION 'Access Denied: Artisan is not registered with your cooperative federation';
        END IF;
    END IF;

    -- Determine status change
    IF p_action = 'APPROVE' THEN
        v_new_status := 'ACTIVE';
    ELSIF p_action = 'REJECT' THEN
        v_new_status := 'REJECTED';
    ELSIF p_action = 'UNDER_REVIEW' OR p_action = 'START_REVIEW' THEN
        v_new_status := 'UNDER_REVIEW';
    ELSIF p_action = 'REQUEST_CHANGES' THEN
        v_new_status := 'CHANGES_REQUIRED';
    ELSIF p_action = 'SUSPEND' THEN
        v_new_status := 'SUSPENDED';
    ELSE
        RAISE EXCEPTION 'Invalid verification action: %', p_action;
    END IF;

    -- Update worker status
    UPDATE public.workers
    SET worker_status = v_new_status,
        is_available = (v_new_status = 'ACTIVE'),
        verification_remarks = COALESCE(p_remarks, verification_remarks),
        updated_at = NOW()
    WHERE id = p_worker_id;

    -- Update or insert worker_verification record
    INSERT INTO public.worker_verification (
        worker_id,
        status,
        reviewed_by,
        reviewed_at,
        rejection_reason,
        updated_at
    ) VALUES (
        p_worker_id,
        CASE WHEN v_new_status = 'ACTIVE' THEN 'APPROVED' ELSE v_new_status END,
        v_caller_id,
        NOW(),
        CASE WHEN v_new_status = 'REJECTED' THEN p_remarks ELSE NULL END,
        NOW()
    )
    ON CONFLICT (worker_id) DO UPDATE
    SET status = EXCLUDED.status,
        reviewed_by = EXCLUDED.reviewed_by,
        reviewed_at = EXCLUDED.reviewed_at,
        rejection_reason = EXCLUDED.rejection_reason,
        updated_at = NOW();

    -- Log action in audit log
    INSERT INTO public.audit_logs (
        actor_id,
        actor_role,
        action,
        entity_type,
        entity_id,
        federation_id,
        new_value,
        reason
    ) VALUES (
        v_caller_id,
        v_actor_role,
        'VERIFY_WORKER_' || p_action,
        'WORKER',
        p_worker_id::text,
        v_worker_fed_id,
        jsonb_build_object('status', v_new_status),
        p_remarks
    );

    RETURN jsonb_build_object(
        'success', true,
        'worker_id', p_worker_id,
        'status', v_new_status,
        'action', p_action
    );
END;
$$;
