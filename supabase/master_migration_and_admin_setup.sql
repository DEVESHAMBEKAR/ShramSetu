-- ============================================================================
-- ShramSetu Master Database Sync & Admin Setup Migration
-- Execute this script in your Supabase SQL Editor (epcevntwhwyrrexlezco)
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Helper Function to get user role
CREATE OR REPLACE FUNCTION public.auth_user_role() RETURNS TEXT AS $$
  SELECT role FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- 1. Ensure columns exist on public.users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Enable RLS and add INSERT policy for users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
CREATE POLICY "Users can insert their own profile" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
CREATE POLICY "Users can view their own profile" ON public.users FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
CREATE POLICY "Users can update their own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
CREATE POLICY "Admins can view all users" ON public.users FOR SELECT USING (public.auth_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "Admins can update all users" ON public.users;
CREATE POLICY "Admins can update all users" ON public.users FOR UPDATE USING (public.auth_user_role() = 'ADMIN');

-- 2. Ensure columns exist on public.services
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS icon_name TEXT;
UPDATE public.services SET icon_name = icon_data WHERE icon_name IS NULL AND icon_data IS NOT NULL;

-- 3. Ensure columns exist on public.workers
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS latitude NUMERIC(10,7);
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS longitude NUMERIC(10,7);
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS review_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Workers can insert own worker profile" ON public.workers;
CREATE POLICY "Workers can insert own worker profile" ON public.workers FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Workers can update own worker profile" ON public.workers;
CREATE POLICY "Workers can update own worker profile" ON public.workers FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Authenticated users can view workers" ON public.workers;
CREATE POLICY "Authenticated users can view workers" ON public.workers FOR SELECT USING (auth.uid() IS NOT NULL AND worker_status = 'ACTIVE');

DROP POLICY IF EXISTS "Admins can manage workers" ON public.workers;
CREATE POLICY "Admins can manage workers" ON public.workers FOR ALL USING (public.auth_user_role() = 'ADMIN');

-- 4. Ensure columns exist on public.payments
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS amount_paise INTEGER;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS razorpay_order_id TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS razorpay_payment_id TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS razorpay_signature TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS escrow_status TEXT NOT NULL DEFAULT 'not_funded';

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Customers can insert their own payments" ON public.payments;
CREATE POLICY "Customers can insert their own payments" ON public.payments FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- 5. Ensure columns exist on public.reviews
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 6. Create KYC worker_verification_documents table if not exists
CREATE TABLE IF NOT EXISTS public.worker_verification_documents (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    worker_id UUID REFERENCES public.workers(id) ON DELETE CASCADE NOT NULL,
    document_type TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    status TEXT DEFAULT 'PENDING',
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
ALTER TABLE public.worker_verification_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Workers can view their own documents" ON public.worker_verification_documents;
CREATE POLICY "Workers can view their own documents" ON public.worker_verification_documents FOR SELECT USING (auth.uid() = worker_id);
DROP POLICY IF EXISTS "Workers can insert their own documents" ON public.worker_verification_documents;
CREATE POLICY "Workers can insert their own documents" ON public.worker_verification_documents FOR INSERT WITH CHECK (auth.uid() = worker_id);

-- 7. Create user_device_tokens table if not exists
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  device_id TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT uq_user_device_token UNIQUE(user_id, fcm_token)
);
ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own device tokens" ON public.user_device_tokens;
CREATE POLICY "Users can view own device tokens" ON public.user_device_tokens FOR SELECT USING (auth.uid() = user_id OR public.auth_user_role() = 'ADMIN');
DROP POLICY IF EXISTS "Users can insert own device tokens" ON public.user_device_tokens;
CREATE POLICY "Users can insert own device tokens" ON public.user_device_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 8. Create notifications table if not exists
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}'::jsonb,
  read_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = recipient_user_id OR public.auth_user_role() = 'ADMIN');
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = recipient_user_id);

-- 9. Create fairmatch_logs table if not exists
CREATE TABLE IF NOT EXISTS public.fairmatch_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  requested_service_id UUID NOT NULL REFERENCES public.services(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  algorithm_version TEXT NOT NULL DEFAULT 'fairmatch_v1',
  weights JSONB NOT NULL,
  candidate_count INTEGER NOT NULL DEFAULT 0,
  top_worker_ids JSONB DEFAULT '[]'::jsonb,
  execution_time_ms INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
ALTER TABLE public.fairmatch_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can view FairMatch logs" ON public.fairmatch_logs;
CREATE POLICY "Admins can view FairMatch logs" ON public.fairmatch_logs FOR SELECT USING (public.auth_user_role() = 'ADMIN');
DROP POLICY IF EXISTS "Authenticated users can record FairMatch logs" ON public.fairmatch_logs;
CREATE POLICY "Authenticated users can record FairMatch logs" ON public.fairmatch_logs FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 10. Create demand_forecasts table if not exists
CREATE TABLE IF NOT EXISTS public.demand_forecasts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  service_id UUID REFERENCES public.services(id) ON DELETE CASCADE,
  service_name TEXT NOT NULL,
  location_key TEXT NOT NULL DEFAULT 'All',
  forecast_date DATE NOT NULL,
  predicted_demand NUMERIC(8,2) NOT NULL,
  lower_bound NUMERIC(8,2),
  upper_bound NUMERIC(8,2),
  model_version TEXT NOT NULL DEFAULT 'demand_forecast_v1',
  horizon_days INTEGER NOT NULL DEFAULT 7,
  data_source TEXT NOT NULL DEFAULT 'live' CHECK (data_source IN ('live', 'synthetic_benchmark')),
  metadata JSONB DEFAULT '{}'::jsonb,
  generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT uq_demand_forecast_point UNIQUE (service_id, location_key, forecast_date, model_version, data_source)
);
ALTER TABLE public.demand_forecasts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can view demand forecasts" ON public.demand_forecasts;
CREATE POLICY "Admins can view demand forecasts" ON public.demand_forecasts FOR SELECT USING (public.auth_user_role() = 'ADMIN');
DROP POLICY IF EXISTS "Admins can insert and update demand forecasts" ON public.demand_forecasts;
CREATE POLICY "Admins can insert and update demand forecasts" ON public.demand_forecasts FOR ALL USING (public.auth_user_role() = 'ADMIN');

-- 11. Triggers & Helper Functions
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, phone, role, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.phone,
    COALESCE(NEW.raw_user_meta_data->>'role', 'CUSTOMER'),
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1), 'User')
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      phone = COALESCE(EXCLUDED.phone, public.users.phone);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger for Review calculation
CREATE OR REPLACE FUNCTION public.update_worker_rating_and_count()
RETURNS TRIGGER AS $func$
DECLARE
  v_worker_id UUID;
  v_avg_rating NUMERIC(3,2);
  v_count INTEGER;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_worker_id := OLD.worker_id;
  ELSE
    v_worker_id := NEW.worker_id;
  END IF;

  SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0.0), COUNT(*)
  INTO v_avg_rating, v_count
  FROM public.reviews
  WHERE worker_id = v_worker_id;

  UPDATE public.workers
  SET rating = v_avg_rating,
      review_count = v_count,
      updated_at = NOW()
  WHERE id = v_worker_id;

  RETURN NULL;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_worker_rating ON public.reviews;
CREATE TRIGGER trg_update_worker_rating
AFTER INSERT OR UPDATE OR DELETE ON public.reviews
FOR EACH ROW
EXECUTE FUNCTION public.update_worker_rating_and_count();

-- 12. ADMIN ACCOUNT SETUP for ambekardevesh2@gmail.com
-- Auto-confirms ambekardevesh2@gmail.com and sets password to admin123
UPDATE auth.users 
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
    confirmed_at = COALESCE(confirmed_at, NOW()),
    encrypted_password = crypt('admin123', gen_salt('bf'))
WHERE email = 'ambekardevesh2@gmail.com';

-- Ensure ADMIN role in public.users
INSERT INTO public.users (id, role, full_name, email, is_active)
SELECT id, 'ADMIN', 'Devesh Ambekar', email, true
FROM auth.users 
WHERE email = 'ambekardevesh2@gmail.com'
ON CONFLICT (id) DO UPDATE 
SET role = 'ADMIN', full_name = 'Devesh Ambekar', is_active = true;
