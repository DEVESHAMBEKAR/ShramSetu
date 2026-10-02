-- Migration 017: Multi-Federation Architecture, Worker Insurance Records, Emergency Bookings, and Digital Invoicing

-- 1. Federations Table (Multi-Federation Support across districts and states)
CREATE TABLE IF NOT EXISTS public.federations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'Maharashtra',
    district TEXT NOT NULL,
    city TEXT NOT NULL,
    registration_no TEXT UNIQUE,
    contact_phone TEXT,
    contact_email TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on Federations
ALTER TABLE public.federations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can view active federations" ON public.federations;
CREATE POLICY "Anyone authenticated can view active federations" ON public.federations
    FOR SELECT USING (is_active = true OR public.auth_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "Admins can manage federations" ON public.federations;
CREATE POLICY "Admins can manage federations" ON public.federations
    FOR ALL USING (public.auth_user_role() = 'ADMIN');

-- Seed initial multi-district cooperative federations
INSERT INTO public.federations (id, name, state, district, city, registration_no, contact_phone) VALUES
    ('11111111-0000-0000-0000-000000000001', 'Pune District Labour Cooperative Federation', 'Maharashtra', 'Pune', 'Pune', 'MH-PUN-COOP-2018-88', '+91 20 2553 4401'),
    ('22222222-0000-0000-0000-000000000002', 'Nashik District Artisans Cooperative Union', 'Maharashtra', 'Nashik', 'Nashik', 'MH-NSK-COOP-2020-14', '+91 253 257 8820'),
    ('33333333-0000-0000-0000-000000000003', 'Mumbai Metropolitan Labour Federation', 'Maharashtra', 'Mumbai City', 'Mumbai', 'MH-MUM-COOP-2016-09', '+91 22 2261 1140'),
    ('44444444-0000-0000-0000-000000000004', 'Chhatrapati Sambhajinagar Labour Federation', 'Maharashtra', 'Chhatrapati Sambhajinagar', 'Chhatrapati Sambhajinagar', 'MH-CSN-COOP-2021-32', '+91 240 233 4560'),
    ('55555555-0000-0000-0000-000000000005', 'Nagpur District Shramik Cooperative Union', 'Maharashtra', 'Nagpur', 'Nagpur', 'MH-NGP-COOP-2019-55', '+91 712 256 7890')
ON CONFLICT (registration_no) DO NOTHING;

-- 2. Extend Workers Table for Multi-Federation & Multi-Service Area Coverage
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS federation_ref_id UUID REFERENCES public.federations(id) ON DELETE SET NULL;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS service_areas TEXT[] DEFAULT '{}';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'Maharashtra';

-- Update existing workers with default federation reference if missing
UPDATE public.workers
SET federation_ref_id = '11111111-0000-0000-0000-000000000001'
WHERE federation_ref_id IS NULL;

-- 3. Worker Insurance Profile & Administration Table
CREATE TABLE IF NOT EXISTS public.worker_insurance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
    provider_name TEXT NOT NULL DEFAULT 'National Insurance Co. / Union Group Policy',
    policy_number TEXT NOT NULL,
    coverage_type TEXT NOT NULL DEFAULT 'Accidental & Medical Health Cover',
    coverage_amount NUMERIC(10,2) NOT NULL DEFAULT 500000.00,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '1 year')::date,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('PENDING', 'ACTIVE', 'EXPIRED', 'SUSPENDED')),
    verification_status TEXT NOT NULL DEFAULT 'VERIFIED' CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    admin_remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on Worker Insurance
ALTER TABLE public.worker_insurance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Workers can view own insurance records" ON public.worker_insurance;
CREATE POLICY "Workers can view own insurance records" ON public.worker_insurance
    FOR SELECT USING (auth.uid() = worker_id);

DROP POLICY IF EXISTS "Admins can manage worker insurance records" ON public.worker_insurance;
CREATE POLICY "Admins can manage worker insurance records" ON public.worker_insurance
    FOR ALL USING (public.auth_user_role() = 'ADMIN');

CREATE INDEX IF NOT EXISTS idx_worker_insurance_worker_id ON public.worker_insurance(worker_id);

-- 4. Emergency Bookings Enhancement
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS booking_type TEXT NOT NULL DEFAULT 'NORMAL';

DO $$
BEGIN
    ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_booking_type_check;
    ALTER TABLE public.bookings ADD CONSTRAINT bookings_booking_type_check
        CHECK (booking_type IN ('NORMAL', 'EMERGENCY'));
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- 5. Digital Invoicing Columns on Payments
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS invoice_id TEXT UNIQUE;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS invoice_data JSONB DEFAULT '{}'::jsonb;

-- Trigger to update updated_at on federations and insurance
CREATE TRIGGER update_federations_updated_at BEFORE UPDATE ON public.federations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_worker_insurance_updated_at BEFORE UPDATE ON public.worker_insurance
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
