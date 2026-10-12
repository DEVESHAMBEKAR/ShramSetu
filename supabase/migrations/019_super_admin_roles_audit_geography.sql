-- Migration 019: Super Admin Role System, Federation Admin Scoping, and Audit Logging
-- This migration extends the existing role system to support SUPER_ADMIN and FEDERATION_ADMIN roles,
-- adds federation admin scope mapping, and creates an immutable audit log table.

-- 1. Extend the users.role CHECK constraint to accept new admin role types
DO $$
BEGIN
    ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
    ALTER TABLE public.users ADD CONSTRAINT users_role_check
        CHECK (role IN ('CUSTOMER', 'WORKER', 'ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not update users_role_check: %', SQLERRM;
END $$;

-- 2. Federation Admin Scope — maps admin users to their authorized federation(s)
CREATE TABLE IF NOT EXISTS public.admin_federation_scope (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    federation_id UUID NOT NULL REFERENCES public.federations(id) ON DELETE CASCADE,
    scope_level TEXT NOT NULL DEFAULT 'FEDERATION' CHECK (scope_level IN ('FEDERATION', 'DISTRICT', 'STATE', 'NATIONAL')),
    assigned_by UUID REFERENCES public.users(id),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    UNIQUE(user_id, federation_id)
);

ALTER TABLE public.admin_federation_scope ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Super admins can manage all scopes" ON public.admin_federation_scope;
CREATE POLICY "Super admins can manage all scopes" ON public.admin_federation_scope
    FOR ALL USING (public.auth_user_role() = 'SUPER_ADMIN');

DROP POLICY IF EXISTS "Admin users can view their own scope" ON public.admin_federation_scope;
CREATE POLICY "Admin users can view their own scope" ON public.admin_federation_scope
    FOR SELECT USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_admin_federation_scope_user ON public.admin_federation_scope(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_federation_scope_federation ON public.admin_federation_scope(federation_id);

-- 3. Audit Logs — immutable record of sensitive administrative actions
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.users(id),
    actor_role TEXT,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT,
    federation_id UUID REFERENCES public.federations(id),
    old_value JSONB,
    new_value JSONB,
    reason TEXT,
    ip_address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Only SUPER_ADMIN and ADMIN can view audit logs
DROP POLICY IF EXISTS "Super admins can view all audit logs" ON public.audit_logs;
CREATE POLICY "Super admins can view all audit logs" ON public.audit_logs
    FOR SELECT USING (public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN'));

-- Any authenticated admin can insert audit logs
DROP POLICY IF EXISTS "Admins can insert audit logs" ON public.audit_logs;
CREATE POLICY "Admins can insert audit logs" ON public.audit_logs
    FOR INSERT WITH CHECK (public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN', 'FEDERATION_ADMIN'));

-- Audit logs are immutable — no updates or deletes allowed
-- (No UPDATE or DELETE policies created intentionally)

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON public.audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON public.audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_federation ON public.audit_logs(federation_id);

-- 4. Add federation_code to federations table for unique human-readable identifiers
ALTER TABLE public.federations ADD COLUMN IF NOT EXISTS federation_code TEXT UNIQUE;

-- Seed federation_code for existing federations from registration_no
UPDATE public.federations
SET federation_code = registration_no
WHERE federation_code IS NULL AND registration_no IS NOT NULL;

-- 5. Update RLS policies across the platform to support new admin role types
DROP POLICY IF EXISTS "Anyone authenticated can view active federations" ON public.federations;
CREATE POLICY "Anyone authenticated can view active federations" ON public.federations
    FOR SELECT USING (is_active = true OR public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can manage federations" ON public.federations;
DROP POLICY IF EXISTS "Only super admins can manage federations" ON public.federations;
CREATE POLICY "Only super admins can manage federations" ON public.federations
    FOR ALL USING (public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN'));

-- 5.1 Users policies for SUPER_ADMIN & FEDERATION_ADMIN
DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
CREATE POLICY "Admins can view all users" ON public.users
    FOR SELECT USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can update all users" ON public.users;
CREATE POLICY "Admins can update all users" ON public.users
    FOR UPDATE USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 5.2 Services & Skills
DROP POLICY IF EXISTS "Admins can manage services" ON public.services;
CREATE POLICY "Admins can manage services" ON public.services
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can manage skills" ON public.skills;
CREATE POLICY "Admins can manage skills" ON public.skills
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 5.3 Workers & Verifications
DROP POLICY IF EXISTS "Admins can manage workers" ON public.workers;
CREATE POLICY "Admins can manage workers" ON public.workers
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can manage worker skills" ON public.worker_skills;
CREATE POLICY "Admins can manage worker skills" ON public.worker_skills
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can manage verifications" ON public.worker_verification;
CREATE POLICY "Admins can manage verifications" ON public.worker_verification
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can view all verification documents" ON public.worker_verification_documents;
CREATE POLICY "Admins can view all verification documents" ON public.worker_verification_documents
    FOR SELECT USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can update verification documents" ON public.worker_verification_documents;
CREATE POLICY "Admins can update verification documents" ON public.worker_verification_documents
    FOR UPDATE USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 5.4 Bookings, Payments, Reviews, Complaints
DROP POLICY IF EXISTS "Admins can view all bookings" ON public.bookings;
CREATE POLICY "Admins can view all bookings" ON public.bookings
    FOR SELECT USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can manage all bookings" ON public.bookings;
CREATE POLICY "Admins can manage all bookings" ON public.bookings
    FOR UPDATE USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can manage payments" ON public.payments;
CREATE POLICY "Admins can manage payments" ON public.payments
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can manage reviews" ON public.reviews;
CREATE POLICY "Admins can manage reviews" ON public.reviews
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can manage complaints" ON public.complaints;
CREATE POLICY "Admins can manage complaints" ON public.complaints
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 5.5 FairMatch & Demand Forecasts
DROP POLICY IF EXISTS "Admins can view FairMatch logs" ON public.fairmatch_logs;
CREATE POLICY "Admins can view FairMatch logs" ON public.fairmatch_logs
    FOR SELECT USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can view demand forecasts" ON public.demand_forecasts;
CREATE POLICY "Admins can view demand forecasts" ON public.demand_forecasts
    FOR SELECT USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can insert and update demand forecasts" ON public.demand_forecasts;
CREATE POLICY "Admins can insert and update demand forecasts" ON public.demand_forecasts
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 5.6 Storage documents
DROP POLICY IF EXISTS "Admins can view all KYC documents" ON storage.objects;
CREATE POLICY "Admins can view all KYC documents" ON storage.objects
    FOR SELECT USING (bucket_id = 'worker-documents' AND public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 6. Update RLS on worker_insurance for new role types
DROP POLICY IF EXISTS "Admins can manage worker insurance records" ON public.worker_insurance;
CREATE POLICY "Admins can manage worker insurance records" ON public.worker_insurance
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 7. Geographic master data — India states and union territories
CREATE TABLE IF NOT EXISTS public.india_states (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL DEFAULT 'STATE' CHECK (type IN ('STATE', 'UNION_TERRITORY')),
    is_active BOOLEAN DEFAULT true
);

-- Seed all 28 states and 8 union territories
INSERT INTO public.india_states (code, name, type) VALUES
    ('AN', 'Andaman and Nicobar Islands', 'UNION_TERRITORY'),
    ('AP', 'Andhra Pradesh', 'STATE'),
    ('AR', 'Arunachal Pradesh', 'STATE'),
    ('AS', 'Assam', 'STATE'),
    ('BR', 'Bihar', 'STATE'),
    ('CH', 'Chandigarh', 'UNION_TERRITORY'),
    ('CT', 'Chhattisgarh', 'STATE'),
    ('DL', 'Delhi', 'UNION_TERRITORY'),
    ('GA', 'Goa', 'STATE'),
    ('GJ', 'Gujarat', 'STATE'),
    ('HR', 'Haryana', 'STATE'),
    ('HP', 'Himachal Pradesh', 'STATE'),
    ('JK', 'Jammu and Kashmir', 'UNION_TERRITORY'),
    ('JH', 'Jharkhand', 'STATE'),
    ('KA', 'Karnataka', 'STATE'),
    ('KL', 'Kerala', 'STATE'),
    ('LA', 'Ladakh', 'UNION_TERRITORY'),
    ('MP', 'Madhya Pradesh', 'STATE'),
    ('MH', 'Maharashtra', 'STATE'),
    ('MN', 'Manipur', 'STATE'),
    ('ML', 'Meghalaya', 'STATE'),
    ('MZ', 'Mizoram', 'STATE'),
    ('NL', 'Nagaland', 'STATE'),
    ('OD', 'Odisha', 'STATE'),
    ('PB', 'Punjab', 'STATE'),
    ('PY', 'Puducherry', 'UNION_TERRITORY'),
    ('RJ', 'Rajasthan', 'STATE'),
    ('SK', 'Sikkim', 'STATE'),
    ('TN', 'Tamil Nadu', 'STATE'),
    ('TG', 'Telangana', 'STATE'),
    ('TR', 'Tripura', 'STATE'),
    ('UP', 'Uttar Pradesh', 'STATE'),
    ('UK', 'Uttarakhand', 'STATE'),
    ('WB', 'West Bengal', 'STATE'),
    ('DN', 'Dadra and Nagar Haveli and Daman and Diu', 'UNION_TERRITORY'),
    ('LD', 'Lakshadweep', 'UNION_TERRITORY')
ON CONFLICT (code) DO NOTHING;

ALTER TABLE public.india_states ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view India states" ON public.india_states;
CREATE POLICY "Anyone can view India states" ON public.india_states
    FOR SELECT USING (true);

-- 8. Super Admin User Bootstrap
-- Automatically confirm and grant SUPER_ADMIN role to specified administrative accounts
UPDATE auth.users 
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email IN ('deveshambekar@gmail.com', 'superadmin@shramsetu.gov.in');

-- Upsert deveshambekar@gmail.com into public.users with SUPER_ADMIN role
INSERT INTO public.users (id, role, full_name, email, is_active)
SELECT id, 'SUPER_ADMIN', COALESCE(raw_user_meta_data->>'full_name', 'Devesh Ambekar'), email, true
FROM auth.users 
WHERE email = 'deveshambekar@gmail.com'
ON CONFLICT (id) DO UPDATE SET role = 'SUPER_ADMIN', full_name = EXCLUDED.full_name, is_active = true;
