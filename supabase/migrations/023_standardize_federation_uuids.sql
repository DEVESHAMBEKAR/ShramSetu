-- ============================================================================
-- Migration 023: Standardize Federation UUIDs to Canonical Sequential Format
-- 1. Updates foreign keys referencing public.federations(id) to support ON UPDATE CASCADE.
-- 2. Standardizes Hyderabad Federation UUID to canonical '66666666-0000-0000-0000-000000000006'.
-- 3. Migrates all worker, scope, and audit references accordingly.
-- 4. Ensures RLS policies allow active federation discovery and administrative creation.
-- ============================================================================

-- 0. Ensure worker and address columns exist idempotently
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS dob DATE;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS trade TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS primary_skill TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS skill_level TEXT DEFAULT 'Intermediate';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS district TEXT DEFAULT 'Pune';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'Maharashtra';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS pincode TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS federation_name TEXT DEFAULT 'Pune District Labour Cooperative Federation';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS federation_ref_id UUID REFERENCES public.federations(id) ON DELETE SET NULL;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS service_areas TEXT[] DEFAULT '{}';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS membership_id TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS verification_remarks TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.users(id);

ALTER TABLE public.addresses ADD COLUMN IF NOT EXISTS district TEXT;

-- 1. Update foreign key constraints to cascade updates cleanly
DO $$
BEGIN
    -- workers.federation_ref_id
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'workers_federation_ref_id_fkey'
          AND table_name = 'workers'
    ) THEN
        ALTER TABLE public.workers DROP CONSTRAINT workers_federation_ref_id_fkey;
        ALTER TABLE public.workers ADD CONSTRAINT workers_federation_ref_id_fkey
            FOREIGN KEY (federation_ref_id) REFERENCES public.federations(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    -- admin_federation_scope.federation_id
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'admin_federation_scope_federation_id_fkey'
          AND table_name = 'admin_federation_scope'
    ) THEN
        ALTER TABLE public.admin_federation_scope DROP CONSTRAINT admin_federation_scope_federation_id_fkey;
        ALTER TABLE public.admin_federation_scope ADD CONSTRAINT admin_federation_scope_federation_id_fkey
            FOREIGN KEY (federation_id) REFERENCES public.federations(id)
            ON UPDATE CASCADE ON DELETE CASCADE;
    END IF;

    -- audit_logs.federation_id
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'audit_logs_federation_id_fkey'
          AND table_name = 'audit_logs'
    ) THEN
        ALTER TABLE public.audit_logs DROP CONSTRAINT audit_logs_federation_id_fkey;
        ALTER TABLE public.audit_logs ADD CONSTRAINT audit_logs_federation_id_fkey
            FOREIGN KEY (federation_id) REFERENCES public.federations(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Constraint update notice: %', SQLERRM;
END $$;

-- 2. Update Hyderabad Federation UUID to canonical sequential format
-- Format: 66666666-0000-0000-0000-000000000006
DO $$
DECLARE
    v_old_id UUID;
    v_target_id UUID := '66666666-0000-0000-0000-000000000006'::UUID;
BEGIN
    -- Check if Hyderabad exists with random or legacy UUID
    SELECT id INTO v_old_id
    FROM public.federations
    WHERE id = '680301cf-90bb-4a66-bef3-3405cc1fef87'::UUID
       OR name ILIKE '%Hyderabad%'
    LIMIT 1;

    IF v_old_id IS NOT NULL THEN
        IF v_old_id <> v_target_id THEN
            -- Update dependent tables if cascade wasn't active
            UPDATE public.workers
            SET federation_ref_id = NULL
            WHERE federation_ref_id = v_old_id;

            UPDATE public.admin_federation_scope
            SET federation_id = v_target_id
            WHERE federation_id = v_old_id;

            UPDATE public.audit_logs
            SET federation_id = v_target_id
            WHERE federation_id = v_old_id;

            -- Update the federation record's primary key ID
            UPDATE public.federations
            SET id = v_target_id,
                name = COALESCE(name, 'Hyderabad District Labour Cooperation'),
                state = 'Telangana',
                district = 'Hyderabad',
                city = 'Hyderabad',
                registration_no = COALESCE(registration_no, 'TS-HYD-COOP-2022-77'),
                contact_phone = COALESCE(contact_phone, '+91 40 2320 0110'),
                is_active = true
            WHERE id = v_old_id;

            -- Restore workers reference with new canonical ID safely
            IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'workers' AND column_name = 'district'
            ) THEN
                EXECUTE 'UPDATE public.workers
                         SET federation_ref_id = $1,
                             federation_name = ''Hyderabad District Labour Cooperation''
                         WHERE district ILIKE ''%Hyderabad%''
                            OR city ILIKE ''%Hyderabad%''
                            OR federation_name ILIKE ''%Hyderabad%'''
                USING v_target_id;
            ELSIF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'workers' AND column_name = 'city'
            ) THEN
                EXECUTE 'UPDATE public.workers
                         SET federation_ref_id = $1
                         WHERE city ILIKE ''%Hyderabad%'''
                USING v_target_id;
            END IF;

            RAISE NOTICE 'Hyderabad Federation updated from % to %', v_old_id, v_target_id;
        ELSE
            RAISE NOTICE 'Hyderabad Federation already uses canonical ID %', v_target_id;
        END IF;
    ELSE
        -- If Hyderabad federation does not exist in DB yet, insert it with canonical UUID
        INSERT INTO public.federations (id, name, state, district, city, registration_no, contact_phone, is_active)
        VALUES (
            v_target_id,
            'Hyderabad District Labour Cooperation',
            'Telangana',
            'Hyderabad',
            'Hyderabad',
            'TS-HYD-COOP-2022-77',
            '+91 40 2320 0110',
            true
        )
        ON CONFLICT (id) DO NOTHING;
        RAISE NOTICE 'Hyderabad Federation inserted with canonical ID %', v_target_id;
    END IF;
END $$;

-- 3. Ensure Row-Level Security allows active federation discovery
DROP POLICY IF EXISTS "Anyone authenticated can view active federations" ON public.federations;
DROP POLICY IF EXISTS "Anyone can view active federations" ON public.federations;
CREATE POLICY "Anyone can view active federations" ON public.federations
    FOR SELECT USING (is_active = true OR public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can manage federations" ON public.federations;
CREATE POLICY "Admins can manage federations" ON public.federations
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN'));
