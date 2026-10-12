-- Migration 024: Worker Insurance Application Pipeline & KYC Access Hardening
-- Allows workers to apply for welfare insurance, and empowers federation admins/super admins
-- to inspect KYC documents and approve policies with unique constraints.

-- 1. Ensure unique constraint on worker_insurance(worker_id) so upsert works reliably
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'worker_insurance_worker_id_unique'
    ) THEN
        -- Clean duplicates if any, keeping latest
        DELETE FROM public.worker_insurance a
        USING public.worker_insurance b
        WHERE a.worker_id = b.worker_id
          AND a.created_at < b.created_at;

        ALTER TABLE public.worker_insurance
        ADD CONSTRAINT worker_insurance_worker_id_unique UNIQUE (worker_id);
    END IF;
END $$;

-- 2. Ensure status check allows PENDING, ACTIVE, EXPIRED, SUSPENDED
ALTER TABLE public.worker_insurance DROP CONSTRAINT IF EXISTS worker_insurance_status_check;
ALTER TABLE public.worker_insurance ADD CONSTRAINT worker_insurance_status_check
    CHECK (status IN ('PENDING', 'ACTIVE', 'EXPIRED', 'SUSPENDED'));

-- 3. RLS for worker_insurance: Workers can view their own, insert new application, or update pending
ALTER TABLE public.worker_insurance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Workers can view own insurance records" ON public.worker_insurance;
CREATE POLICY "Workers can view own insurance records" ON public.worker_insurance
    FOR SELECT USING (auth.uid() = worker_id);

DROP POLICY IF EXISTS "Workers can apply for own insurance" ON public.worker_insurance;
CREATE POLICY "Workers can apply for own insurance" ON public.worker_insurance
    FOR INSERT WITH CHECK (auth.uid() = worker_id);

DROP POLICY IF EXISTS "Workers can update own pending insurance" ON public.worker_insurance;
CREATE POLICY "Workers can update own pending insurance" ON public.worker_insurance
    FOR UPDATE USING (auth.uid() = worker_id AND status = 'PENDING');

-- 4. Admins can view, insert, and update all worker insurance records
DROP POLICY IF EXISTS "Admins can manage worker insurance records" ON public.worker_insurance;
CREATE POLICY "Admins can manage worker insurance records" ON public.worker_insurance
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 5. KYC Storage Objects RLS: Ensure all admin tiers can view KYC documents
DROP POLICY IF EXISTS "Admins can view all KYC documents" ON storage.objects;
CREATE POLICY "Admins can view all KYC documents" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'worker-documents' AND
        public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN')
    );

-- 6. Ensure Super Admins and Federation Admins can view and update verification documents
DROP POLICY IF EXISTS "Admins can view all verification documents" ON public.worker_verification_documents;
CREATE POLICY "Admins can view all verification documents" ON public.worker_verification_documents
    FOR SELECT USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can update verification documents" ON public.worker_verification_documents;
CREATE POLICY "Admins can update verification documents" ON public.worker_verification_documents
    FOR UPDATE USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));
