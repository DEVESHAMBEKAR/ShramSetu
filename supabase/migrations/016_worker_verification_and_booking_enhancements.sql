-- Migration 016: Worker Verification, Verification History & Booking Actions Enhancement

-- 1. Enhance Workers Table with required 20-field profile & verification metadata
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

-- Update worker_status check constraint to support full verification lifecycle
DO $$
BEGIN
    ALTER TABLE public.workers DROP CONSTRAINT IF EXISTS workers_worker_status_check;
    ALTER TABLE public.workers ADD CONSTRAINT workers_worker_status_check
        CHECK (worker_status IN ('ACTIVE', 'INACTIVE', 'PENDING_VERIFICATION', 'UNDER_REVIEW', 'CHANGES_REQUIRED', 'REJECTED', 'SUSPENDED'));
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- 2. Enhance Worker Verification Table
DO $$
BEGIN
    ALTER TABLE public.worker_verification DROP CONSTRAINT IF EXISTS worker_verification_status_check;
    ALTER TABLE public.worker_verification ADD CONSTRAINT worker_verification_status_check
        CHECK (status IN ('NOT_SUBMITTED', 'PENDING', 'UNDER_REVIEW', 'CHANGES_REQUIRED', 'APPROVED', 'REJECTED', 'SUSPENDED'));
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.worker_verification ADD COLUMN IF NOT EXISTS remarks TEXT;
ALTER TABLE public.worker_verification ADD COLUMN IF NOT EXISTS action_history JSONB DEFAULT '[]'::jsonb;

-- 3. Create Immutable Worker Verification History (Audit Trail)
CREATE TABLE IF NOT EXISTS public.worker_verification_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
    admin_id UUID REFERENCES public.users(id),
    previous_status TEXT,
    new_status TEXT NOT NULL,
    action TEXT NOT NULL,
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on verification history
ALTER TABLE public.worker_verification_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view verification history" ON public.worker_verification_history;
CREATE POLICY "Admins can view verification history" ON public.worker_verification_history
    FOR SELECT USING (public.auth_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "Admins can insert verification history" ON public.worker_verification_history;
CREATE POLICY "Admins can insert verification history" ON public.worker_verification_history
    FOR INSERT WITH CHECK (public.auth_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "Workers can view own verification history" ON public.worker_verification_history;
CREATE POLICY "Workers can view own verification history" ON public.worker_verification_history
    FOR SELECT USING (auth.uid() = worker_id);

-- 4. Enhance Bookings Table with Cancellation & Rescheduling tracking
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES public.users(id);
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS rescheduled_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS previous_scheduled_date DATE;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS previous_scheduled_time TIME;

-- 5. Helper Function / RPC for Admin Worker Verification Action
CREATE OR REPLACE FUNCTION public.admin_verify_worker(
    p_worker_id UUID,
    p_action TEXT, -- 'START_REVIEW', 'APPROVE', 'REQUEST_CHANGES', 'REJECT', 'SUSPEND'
    p_remarks TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_admin_id UUID;
    v_prev_status TEXT;
    v_new_status TEXT;
    v_result JSONB;
BEGIN
    v_admin_id := auth.uid();
    
    -- Verify caller is admin
    IF public.auth_user_role() <> 'ADMIN' THEN
        RAISE EXCEPTION 'Access denied. Administrator privileges required.';
    END IF;

    -- Fetch current status
    SELECT worker_status INTO v_prev_status FROM public.workers WHERE id = p_worker_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Worker record not found for id %', p_worker_id;
    END IF;

    -- Determine new status based on action
    CASE p_action
        WHEN 'START_REVIEW' THEN
            v_new_status := 'UNDER_REVIEW';
        WHEN 'APPROVE' THEN
            v_new_status := 'ACTIVE';
        WHEN 'REQUEST_CHANGES' THEN
            v_new_status := 'CHANGES_REQUIRED';
        WHEN 'REJECT' THEN
            v_new_status := 'REJECTED';
        WHEN 'SUSPEND' THEN
            v_new_status := 'SUSPENDED';
        ELSE
            RAISE EXCEPTION 'Invalid verification action %', p_action;
    END CASE;

    -- Update workers table
    UPDATE public.workers
    SET worker_status = v_new_status,
        verification_remarks = COALESCE(p_remarks, verification_remarks),
        reviewed_by = v_admin_id,
        verified_at = CASE WHEN v_new_status = 'ACTIVE' THEN NOW() ELSE verified_at END,
        updated_at = NOW()
    WHERE id = p_worker_id;

    -- Update or insert worker_verification table
    INSERT INTO public.worker_verification (worker_id, status, reviewed_at, reviewed_by, rejection_reason, remarks, updated_at)
    VALUES (
        p_worker_id,
        CASE
            WHEN v_new_status = 'ACTIVE' THEN 'APPROVED'
            WHEN v_new_status = 'CHANGES_REQUIRED' THEN 'CHANGES_REQUIRED'
            WHEN v_new_status = 'UNDER_REVIEW' THEN 'UNDER_REVIEW'
            WHEN v_new_status = 'SUSPENDED' THEN 'SUSPENDED'
            WHEN v_new_status = 'REJECTED' THEN 'REJECTED'
            ELSE 'PENDING'
        END,
        NOW(),
        v_admin_id,
        CASE WHEN v_new_status = 'REJECTED' THEN p_remarks ELSE NULL END,
        p_remarks,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET status = EXCLUDED.status,
        reviewed_at = EXCLUDED.reviewed_at,
        reviewed_by = EXCLUDED.reviewed_by,
        rejection_reason = EXCLUDED.rejection_reason,
        remarks = EXCLUDED.remarks,
        updated_at = NOW();

    -- Log in immutable verification history
    INSERT INTO public.worker_verification_history (
        worker_id,
        admin_id,
        previous_status,
        new_status,
        action,
        remarks
    ) VALUES (
        p_worker_id,
        v_admin_id,
        v_prev_status,
        v_new_status,
        p_action,
        p_remarks
    );

    v_result := jsonb_build_object(
        'success', true,
        'worker_id', p_worker_id,
        'previous_status', v_prev_status,
        'new_status', v_new_status,
        'action', p_action,
        'remarks', p_remarks
    );

    RETURN v_result;
END;
$$;
