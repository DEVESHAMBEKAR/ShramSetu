-- 1. Add avatar_url to users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url text;

-- 2. Create KYC documents table
CREATE TABLE IF NOT EXISTS public.worker_verification_documents (
    id uuid default gen_random_uuid() primary key,
    worker_id uuid references public.workers(id) on delete cascade not null,
    document_type text not null, -- 'IDENTITY', 'ADDRESS', 'SKILL_CERTIFICATE'
    storage_path text not null,
    file_name text not null,
    mime_type text not null,
    file_size integer not null,
    status text default 'PENDING',
    rejection_reason text,
    created_at timestamp with time zone default now()
);

-- 3. RLS for worker_verification_documents
ALTER TABLE public.worker_verification_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Workers can view their own documents" ON public.worker_verification_documents
    FOR SELECT USING (auth.uid() = worker_id);

CREATE POLICY "Workers can insert their own documents" ON public.worker_verification_documents
    FOR INSERT WITH CHECK (auth.uid() = worker_id);

CREATE POLICY "Workers can update their own documents" ON public.worker_verification_documents
    FOR UPDATE USING (auth.uid() = worker_id);

CREATE POLICY "Workers can delete their own documents" ON public.worker_verification_documents
    FOR DELETE USING (auth.uid() = worker_id);

CREATE POLICY "Admins can view all verification documents" ON public.worker_verification_documents
    FOR SELECT USING (public.auth_user_role() = 'ADMIN');

CREATE POLICY "Admins can update verification documents" ON public.worker_verification_documents
    FOR UPDATE USING (public.auth_user_role() = 'ADMIN');

-- 4. Create Buckets
INSERT INTO storage.buckets (id, name, public) VALUES ('profile-images', 'profile-images', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('worker-documents', 'worker-documents', false) ON CONFLICT (id) DO NOTHING;

-- 5. Storage RLS Policies
-- We must enable RLS on storage.objects if it's not already enabled (Supabase enables it by default)

-- Profile Images (Public read, Authenticated write for own folder)
CREATE POLICY "Public Profile Images View" ON storage.objects FOR SELECT USING (bucket_id = 'profile-images');
CREATE POLICY "Users can upload own profile image" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'profile-images' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can update own profile image" ON storage.objects FOR UPDATE USING (bucket_id = 'profile-images' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete own profile image" ON storage.objects FOR DELETE USING (bucket_id = 'profile-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- KYC Documents (Private, Worker read/write own, Admin read all)
CREATE POLICY "Workers can view own KYC documents" ON storage.objects FOR SELECT USING (bucket_id = 'worker-documents' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Workers can upload own KYC documents" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'worker-documents' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Workers can update own KYC documents" ON storage.objects FOR UPDATE USING (bucket_id = 'worker-documents' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Workers can delete own KYC documents" ON storage.objects FOR DELETE USING (bucket_id = 'worker-documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Admins can view all KYC documents" ON storage.objects FOR SELECT USING (bucket_id = 'worker-documents' AND public.auth_user_role() = 'ADMIN');
