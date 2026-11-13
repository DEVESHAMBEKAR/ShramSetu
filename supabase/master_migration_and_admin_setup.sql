-- ============================================================================
-- ShramSetu Master Database Sync & Admin Setup Migration
-- Execute this complete script in Supabase SQL Editor (epcevntwhwyrrexlezco)
-- ============================================================================

-- 0. Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Helper Function to get user role
CREATE OR REPLACE FUNCTION public.auth_user_role() RETURNS TEXT AS $$
  SELECT role FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- 1. Table Updates & Columns
-- 1.1 Users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check
  CHECK (role IN ('CUSTOMER', 'WORKER', 'ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
CREATE POLICY "Users can insert their own profile" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
CREATE POLICY "Users can view their own profile" ON public.users FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
CREATE POLICY "Users can update their own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
CREATE POLICY "Admins can view all users" ON public.users FOR SELECT USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can update all users" ON public.users;
CREATE POLICY "Admins can update all users" ON public.users FOR UPDATE USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 1.2 Services
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS icon_name TEXT;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view services" ON public.services;
CREATE POLICY "Authenticated users can view services" ON public.services FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);

DROP POLICY IF EXISTS "Admins can manage services" ON public.services;
CREATE POLICY "Admins can manage services" ON public.services FOR ALL USING (public.auth_user_role() = 'ADMIN');

-- 1.3 Workers
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS latitude NUMERIC(10,7);
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS longitude NUMERIC(10,7);
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS review_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Workers can insert own worker profile" ON public.workers;
CREATE POLICY "Workers can insert own worker profile" ON public.workers FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Workers can update own worker profile" ON public.workers;
CREATE POLICY "Workers can update own worker profile" ON public.workers FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Workers can view own worker profile" ON public.workers;
CREATE POLICY "Workers can view own worker profile" ON public.workers FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Authenticated users can view workers" ON public.workers;
CREATE POLICY "Authenticated users can view workers" ON public.workers FOR SELECT USING (auth.uid() IS NOT NULL AND worker_status = 'ACTIVE');

DROP POLICY IF EXISTS "Admins can manage workers" ON public.workers;
CREATE POLICY "Admins can manage workers" ON public.workers FOR ALL USING (public.auth_user_role() = 'ADMIN');

-- 1.4 Payments
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS amount_paise INTEGER;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS razorpay_order_id TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS razorpay_payment_id TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS razorpay_signature TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS escrow_status TEXT NOT NULL DEFAULT 'not_funded';

ALTER TABLE public.payments DROP CONSTRAINT IF EXISTS payments_status_check;
ALTER TABLE public.payments ADD CONSTRAINT payments_status_check 
  CHECK (status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED', 'CANCELLED'));

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Customers can insert their own payments" ON public.payments;
CREATE POLICY "Customers can insert their own payments" ON public.payments FOR INSERT WITH CHECK (auth.uid() = customer_id);

DROP POLICY IF EXISTS "Customers can view their own payments" ON public.payments;
CREATE POLICY "Customers can view their own payments" ON public.payments FOR SELECT USING (auth.uid() = customer_id);

DROP POLICY IF EXISTS "Workers can view their own payments" ON public.payments;
CREATE POLICY "Workers can view their own payments" ON public.payments FOR SELECT USING (auth.uid() = worker_id);

DROP POLICY IF EXISTS "Admins can manage payments" ON public.payments;
CREATE POLICY "Admins can manage payments" ON public.payments FOR ALL USING (public.auth_user_role() = 'ADMIN');

-- 1.5 Reviews
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view reviews" ON public.reviews;
CREATE POLICY "Anyone can view reviews" ON public.reviews FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Customers can create reviews for their bookings" ON public.reviews;
CREATE POLICY "Customers can create reviews for their bookings" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = customer_id);

DROP POLICY IF EXISTS "Customers can update their own reviews" ON public.reviews;
CREATE POLICY "Customers can update their own reviews" ON public.reviews FOR UPDATE USING (auth.uid() = customer_id);

DROP POLICY IF EXISTS "Admins can manage reviews" ON public.reviews;
CREATE POLICY "Admins can manage reviews" ON public.reviews FOR ALL USING (public.auth_user_role() = 'ADMIN');

-- 2. New Infrastructure Tables
-- 2.1 Worker Verification Documents (KYC)
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
DROP POLICY IF EXISTS "Admins can view all verification documents" ON public.worker_verification_documents;
CREATE POLICY "Admins can view all verification documents" ON public.worker_verification_documents FOR SELECT USING (public.auth_user_role() = 'ADMIN');
DROP POLICY IF EXISTS "Admins can update verification documents" ON public.worker_verification_documents;
CREATE POLICY "Admins can update verification documents" ON public.worker_verification_documents FOR UPDATE USING (public.auth_user_role() = 'ADMIN');

-- 2.2 Device Tokens (FCM)
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
DROP POLICY IF EXISTS "Users can update own device tokens" ON public.user_device_tokens;
CREATE POLICY "Users can update own device tokens" ON public.user_device_tokens FOR UPDATE USING (auth.uid() = user_id);

-- 2.3 Notifications
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

-- 2.4 FairMatch Research Logs
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

-- 2.5 Demand Forecasts
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

-- 3. Supabase Realtime Setup
-- Set replica identity to FULL so UPDATE and DELETE events include all columns
ALTER TABLE public.bookings REPLICA IDENTITY FULL;

-- Add public.bookings to realtime publication if not already present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'bookings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
  END IF;
END $$;

-- 4. Supabase Storage Buckets
INSERT INTO storage.buckets (id, name, public) VALUES ('profile-images', 'profile-images', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('worker-documents', 'worker-documents', false) ON CONFLICT (id) DO NOTHING;

-- Storage Policies
DROP POLICY IF EXISTS "Public Profile Images View" ON storage.objects;
CREATE POLICY "Public Profile Images View" ON storage.objects FOR SELECT USING (bucket_id = 'profile-images');

DROP POLICY IF EXISTS "Users can upload own profile image" ON storage.objects;
CREATE POLICY "Users can upload own profile image" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'profile-images' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Workers can view own KYC documents" ON storage.objects;
CREATE POLICY "Workers can view own KYC documents" ON storage.objects FOR SELECT USING (bucket_id = 'worker-documents' AND (auth.uid()::text = (storage.foldername(name))[1] OR public.auth_user_role() = 'ADMIN'));

DROP POLICY IF EXISTS "Workers can upload own KYC documents" ON storage.objects;
CREATE POLICY "Workers can upload own KYC documents" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'worker-documents' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 5. Business Logic RPCs
-- 5.1 Haversine Distance
CREATE OR REPLACE FUNCTION public.calculate_haversine_distance(
  lat1 NUMERIC, lon1 NUMERIC, lat2 NUMERIC, lon2 NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
  v_earth_radius NUMERIC := 6371.0;
  v_dlat NUMERIC;
  v_dlon NUMERIC;
  v_a NUMERIC;
  v_c NUMERIC;
BEGIN
  IF lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN
    RETURN NULL;
  END IF;
  v_dlat := radians(lat2 - lat1);
  v_dlon := radians(lon2 - lon1);
  v_a := sin(v_dlat / 2.0) ^ 2.0 + cos(radians(lat1)) * cos(radians(lat2)) * sin(v_dlon / 2.0) ^ 2.0;
  v_c := 2.0 * atan2(sqrt(v_a), sqrt(GREATEST(0.0, 1.0 - v_a)));
  RETURN ROUND((v_earth_radius * v_c)::numeric, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 5.2 FairMatch Recommendation RPC
CREATE OR REPLACE FUNCTION public.fairmatch_recommend_workers(
  p_service_id UUID,
  p_customer_lat NUMERIC DEFAULT NULL,
  p_customer_lng NUMERIC DEFAULT NULL,
  p_weights JSONB DEFAULT NULL,
  p_limit INTEGER DEFAULT 10,
  p_algorithm TEXT DEFAULT 'fairmatch_v1'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_start_time TIMESTAMPTZ := clock_timestamp();
  v_w_skill NUMERIC := 0.35;
  v_w_dist NUMERIC := 0.20;
  v_w_avail NUMERIC := 0.15;
  v_w_rating NUMERIC := 0.10;
  v_w_exp NUMERIC := 0.10;
  v_w_fairness NUMERIC := 0.10;
  v_effective_weights JSONB;
  v_worker_list JSONB := '[]'::jsonb;
  v_top_worker_ids JSONB := '[]'::jsonb;
  v_candidate_count INTEGER := 0;
  v_exec_ms INTEGER := 0;
BEGIN
  IF p_algorithm = 'nearest' THEN
    v_w_skill := 0.0; v_w_dist := 1.0; v_w_avail := 0.0; v_w_rating := 0.0; v_w_exp := 0.0; v_w_fairness := 0.0;
  ELSIF p_algorithm = 'highest_rated' THEN
    v_w_skill := 0.0; v_w_dist := 0.0; v_w_avail := 0.0; v_w_rating := 1.0; v_w_exp := 0.0; v_w_fairness := 0.0;
  ELSIF p_weights IS NOT NULL THEN
    v_w_skill := COALESCE((p_weights->>'skill')::numeric, v_w_skill);
    v_w_dist := COALESCE((p_weights->>'distance')::numeric, v_w_dist);
    v_w_avail := COALESCE((p_weights->>'availability')::numeric, v_w_avail);
    v_w_rating := COALESCE((p_weights->>'rating')::numeric, v_w_rating);
    v_w_exp := COALESCE((p_weights->>'experience')::numeric, v_w_exp);
    v_w_fairness := COALESCE((p_weights->>'fairness')::numeric, v_w_fairness);
  END IF;

  v_effective_weights := jsonb_build_object(
    'skill', v_w_skill, 'distance', v_w_dist, 'availability', v_w_avail,
    'rating', v_w_rating, 'experience', v_w_exp, 'fairness', v_w_fairness
  );

  WITH eligible_candidates AS (
    SELECT 
      w.id AS worker_id,
      u.full_name,
      u.avatar_url,
      COALESCE(w.rating, 0.0) AS rating,
      COALESCE(w.review_count, 0) AS review_count,
      COALESCE(w.completed_jobs, 0) AS completed_jobs,
      COALESCE(w.experience_years, 1) AS experience_years,
      COALESCE(w.location_tag, 'Pune Area') AS location_tag,
      w.bio,
      w.latitude,
      w.longitude,
      w.is_union_gold,
      w.is_coop_master,
      COALESCE(public.calculate_haversine_distance(p_customer_lat, p_customer_lng, w.latitude, w.longitude), 2.0) AS distance_km,
      (w.latitude IS NOT NULL AND p_customer_lat IS NOT NULL) AS has_coordinates,
      COALESCE((
        SELECT COUNT(*)::int FROM public.bookings b
        WHERE b.worker_id = w.id AND b.status IN ('accepted', 'onTheWay', 'arrived', 'inProgress')
      ), 0) AS active_bookings_count,
      COALESCE((
        SELECT COUNT(*)::int FROM public.bookings b
        WHERE b.worker_id = w.id AND b.status = 'completed' AND b.created_at >= (NOW() - INTERVAL '7 days')
      ), 0) AS recent_7d_bookings_count
    FROM public.workers w
    INNER JOIN public.users u ON u.id = w.id
    INNER JOIN public.worker_skills ws ON ws.worker_id = w.id AND ws.skill_id = p_service_id
    WHERE w.worker_status = 'ACTIVE' AND w.is_available = true
  ),
  scored_candidates AS (
    SELECT 
      c.*,
      1.0::numeric AS skill_score,
      CASE WHEN c.has_coordinates THEN GREATEST(0.0, ROUND((1.0 - (c.distance_km / 15.0))::numeric, 4)) ELSE 0.5::numeric END AS distance_score,
      1.0::numeric AS availability_score,
      CASE WHEN c.review_count > 0 THEN GREATEST(0.0, LEAST(1.0, ROUND(((c.rating - 1.0) / 4.0)::numeric, 4))) ELSE 0.5::numeric END AS rating_score,
      GREATEST(0.0, LEAST(1.0, ROUND((c.experience_years::numeric / 10.0), 4))) AS experience_score,
      GREATEST(0.0, ROUND((1.0 - (LEAST(10.0, (c.active_bookings_count * 2.0 + c.recent_7d_bookings_count)::numeric) / 10.0))::numeric, 4)) AS fairness_score
    FROM eligible_candidates c
  ),
  ranked_candidates AS (
    SELECT 
      s.*,
      ROUND((v_w_skill * s.skill_score + v_w_dist * s.distance_score + v_w_avail * s.availability_score + v_w_rating * s.rating_score + v_w_exp * s.experience_score + v_w_fairness * s.fairness_score)::numeric, 4) AS total_score,
      ARRAY_REMOVE(ARRAY[
        'Verified Skill', 'Available Now',
        CASE WHEN s.distance_score >= 0.6 THEN 'Nearby' ELSE NULL END,
        CASE WHEN s.rating >= 4.5 AND s.review_count >= 1 THEN 'Top Rated' WHEN s.rating_score >= 0.6 THEN 'Good Rating' ELSE NULL END,
        CASE WHEN s.experience_years >= 8 THEN 'Veteran Artisan' WHEN s.experience_years >= 4 THEN 'Experienced' ELSE NULL END,
        CASE WHEN s.fairness_score >= 0.7 THEN 'Cooperative Partner' ELSE NULL END
      ], NULL) AS explanation_tags
    FROM scored_candidates s
  )
  SELECT 
    COUNT(*)::int,
    jsonb_agg(
      jsonb_build_object(
        'id', r.worker_id,
        'name', r.full_name,
        'avatar_url', r.avatar_url,
        'rating', r.rating,
        'review_count', r.review_count,
        'completed_jobs', r.completed_jobs,
        'experience_years', r.experience_years,
        'distance_km', r.distance_km,
        'location_tag', r.location_tag,
        'bio', r.bio,
        'is_union_gold', r.is_union_gold,
        'is_coop_master', r.is_coop_master,
        'total_score', r.total_score,
        'skill_score', r.skill_score,
        'distance_score', r.distance_score,
        'availability_score', r.availability_score,
        'rating_score', r.rating_score,
        'experience_score', r.experience_score,
        'fairness_score', r.fairness_score,
        'explanation_tags', to_jsonb(r.explanation_tags)
      )
      ORDER BY r.total_score DESC, r.skill_score DESC, r.distance_km ASC, r.worker_id ASC
    )
  INTO v_candidate_count, v_worker_list
  FROM (
    SELECT * FROM ranked_candidates 
    ORDER BY total_score DESC, skill_score DESC, distance_km ASC, worker_id ASC 
    LIMIT p_limit
  ) r;

  v_worker_list := COALESCE(v_worker_list, '[]'::jsonb);
  v_candidate_count := COALESCE(v_candidate_count, 0);

  SELECT COALESCE(jsonb_agg(w->>'id'), '[]'::jsonb)
  INTO v_top_worker_ids
  FROM jsonb_array_elements(v_worker_list) w;

  v_exec_ms := (EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000)::int;

  BEGIN
    INSERT INTO public.fairmatch_logs (
      requested_service_id, customer_id, algorithm_version, weights, candidate_count, top_worker_ids, execution_time_ms, created_at
    ) VALUES (
      p_service_id, auth.uid(), COALESCE(p_algorithm, 'fairmatch_v1'), v_effective_weights, v_candidate_count, v_top_worker_ids, v_exec_ms, NOW()
    );
  EXCEPTION WHEN OTHERS THEN NULL; END;

  RETURN jsonb_build_object(
    'success', true,
    'algorithm', COALESCE(p_algorithm, 'fairmatch_v1'),
    'candidate_count', v_candidate_count,
    'execution_time_ms', v_exec_ms,
    'weights', v_effective_weights,
    'workers', v_worker_list
  );
END;
$func$;

-- 5.3 Historical Booking Demand Aggregation RPC
CREATE OR REPLACE FUNCTION public.get_historical_booking_demand(
  p_service_id UUID DEFAULT NULL,
  p_location_key TEXT DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
  demand_date DATE,
  service_id UUID,
  service_name TEXT,
  location_key TEXT,
  booking_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.auth_user_role() <> 'ADMIN' THEN
    RAISE EXCEPTION 'Unauthorized: Only federation administrators can access historical demand aggregations.';
  END IF;

  RETURN QUERY
  SELECT 
    b.scheduled_date AS demand_date,
    b.service_id,
    s.name AS service_name,
    COALESCE(a.area, w.location_tag, 'Pune General') AS location_key,
    COUNT(b.id) AS booking_count
  FROM public.bookings b
  JOIN public.services s ON s.id = b.service_id
  LEFT JOIN public.addresses a ON a.id = b.address_id
  LEFT JOIN public.workers w ON w.id = b.worker_id
  WHERE b.status IN ('completed', 'inProgress', 'accepted', 'pending')
    AND (p_service_id IS NULL OR b.service_id = p_service_id)
    AND (p_location_key IS NULL OR p_location_key = 'All' OR COALESCE(a.area, w.location_tag, 'Pune General') = p_location_key)
    AND (p_start_date IS NULL OR b.scheduled_date >= p_start_date)
    AND (p_end_date IS NULL OR b.scheduled_date <= p_end_date)
  GROUP BY b.scheduled_date, b.service_id, s.name, COALESCE(a.area, w.location_tag, 'Pune General')
  ORDER BY demand_date ASC;
END;
$$;

-- 5.4 Escrow Release RPC
CREATE OR REPLACE FUNCTION public.release_escrow_for_booking(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_payment RECORD;
  v_booking RECORD;
BEGIN
  SELECT * INTO v_payment FROM public.payments WHERE booking_id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Payment not found');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
  IF v_booking.status != 'completed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not completed');
  END IF;

  IF v_payment.escrow_status != 'held' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Escrow not in held state: ' || v_payment.escrow_status);
  END IF;

  UPDATE public.payments SET escrow_status = 'released', updated_at = NOW() WHERE booking_id = p_booking_id;
  UPDATE public.workers SET completed_jobs = completed_jobs + 1, updated_at = NOW() WHERE id = v_payment.worker_id;

  RETURN jsonb_build_object('success', true, 'released_amount', v_payment.amount);
END;
$func$;

-- 5.5 Reviews & Ratings RPC
CREATE OR REPLACE FUNCTION public.submit_booking_review(
  p_booking_id UUID,
  p_rating INTEGER,
  p_comment TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_customer_id UUID;
  v_worker_id UUID;
  v_booking_status TEXT;
  v_review_id UUID;
  v_created_at TIMESTAMPTZ;
  v_existing RECORD;
BEGIN
  v_customer_id := auth.uid();
  IF v_customer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  IF p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rating must be between 1 and 5');
  END IF;

  SELECT worker_id, status INTO v_worker_id, v_booking_status
  FROM public.bookings WHERE id = p_booking_id AND customer_id = v_customer_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or does not belong to you');
  END IF;

  IF v_booking_status != 'completed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only completed bookings can be reviewed');
  END IF;

  SELECT id INTO v_existing FROM public.reviews WHERE booking_id = p_booking_id;
  IF FOUND THEN
    UPDATE public.reviews SET rating = p_rating, comment = TRIM(p_comment), updated_at = NOW()
    WHERE id = v_existing.id RETURNING id, created_at INTO v_review_id, v_created_at;
    RETURN jsonb_build_object('success', true, 'review_id', v_review_id, 'is_update', true);
  END IF;

  INSERT INTO public.reviews (booking_id, customer_id, worker_id, rating, comment, created_at, updated_at)
  VALUES (p_booking_id, v_customer_id, v_worker_id, p_rating, TRIM(p_comment), NOW(), NOW())
  RETURNING id, created_at INTO v_review_id, v_created_at;

  RETURN jsonb_build_object('success', true, 'review_id', v_review_id, 'is_update', false);
END;
$func$;

-- Trigger for worker rating recalculation
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
  FROM public.reviews WHERE worker_id = v_worker_id;

  UPDATE public.workers SET rating = v_avg_rating, review_count = v_count, updated_at = NOW() WHERE id = v_worker_id;
  RETURN NULL;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_worker_rating ON public.reviews;
CREATE TRIGGER trg_update_worker_rating
AFTER INSERT OR UPDATE OR DELETE ON public.reviews
FOR EACH ROW EXECUTE FUNCTION public.update_worker_rating_and_count();

-- 5.6 Device Token Registration RPC
CREATE OR REPLACE FUNCTION public.register_device_token(
  p_fcm_token TEXT,
  p_platform TEXT DEFAULT 'android',
  p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_user_id UUID;
  v_token_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  INSERT INTO public.user_device_tokens (user_id, fcm_token, platform, device_id, is_active, last_seen_at, updated_at)
  VALUES (v_user_id, TRIM(p_fcm_token), COALESCE(p_platform, 'android'), p_device_id, true, NOW(), NOW())
  ON CONFLICT (user_id, fcm_token) DO UPDATE
  SET is_active = true, platform = EXCLUDED.platform, last_seen_at = NOW(), updated_at = NOW()
  RETURNING id INTO v_token_id;

  RETURN jsonb_build_object('success', true, 'id', v_token_id);
END;
$func$;

CREATE OR REPLACE FUNCTION public.deactivate_device_token(p_fcm_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
BEGIN
  UPDATE public.user_device_tokens SET is_active = false, updated_at = NOW()
  WHERE user_id = auth.uid() AND fcm_token = TRIM(p_fcm_token);
  RETURN jsonb_build_object('success', true);
END;
$func$;

-- 5.7 Auto User Profile Handler Trigger
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
  SET email = EXCLUDED.email, phone = COALESCE(EXCLUDED.phone, public.users.phone);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 6. Master Seed Data (Services & Skills)
INSERT INTO public.services (id, name, description, category, icon_name, icon_data, is_active) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Electrician', 'Electrical repairs, wiring, and appliance installation', 'Home Maintenance', 'electrical_services', 'electrical_services', true),
  ('22222222-2222-2222-2222-222222222222', 'Plumber', 'Pipe fixing, leak repairs, and sanitary installation', 'Home Maintenance', 'plumbing', 'plumbing', true),
  ('33333333-3333-3333-3333-333333333333', 'Carpenter', 'Furniture repairs, woodworking, and door fixtures', 'Home Maintenance', 'carpenter', 'carpenter', true),
  ('44444444-4444-4444-4444-444444444444', 'Painter', 'Interior/exterior painting, touch-ups, and wall decor', 'Home Maintenance', 'format_paint', 'format_paint', true),
  ('55555555-5555-5555-5555-555555555555', 'Cleaner', 'Deep house cleaning, kitchen scrubbing, and sanitization', 'Cleaning', 'cleaning_services', 'cleaning_services', true),
  ('66666666-6666-6666-6666-666666666666', 'Caregiver', 'Elderly assistance, patient care, and home nursing', 'Care', 'elderly', 'elderly', true),
  ('77777777-7777-7777-7777-777777777777', 'Driver', 'Chauffeur services, hourly trips, and station transit', 'Transport', 'drive_eta', 'drive_eta', true),
  ('88888888-8888-8888-8888-888888888888', 'Gardener', 'Lawn mowing, landscape trimming, and plant care', 'Home Maintenance', 'yard', 'yard', true),
  ('99999999-9999-9999-9999-999999999999', 'Technician', 'AC repair, washing machine servicing, and appliance fixes', 'Home Maintenance', 'build', 'build', true)
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name, description = EXCLUDED.description, category = EXCLUDED.category, 
    icon_name = EXCLUDED.icon_name, icon_data = EXCLUDED.icon_data, is_active = EXCLUDED.is_active;

INSERT INTO public.skills (id, name) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'AC Repair'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Washing Machine Repair'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Wiring'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Pipe Leakage')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 7. ADMIN Setup for ambekardevesh2@gmail.com
UPDATE auth.users 
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
    encrypted_password = crypt('admin123', gen_salt('bf'))
WHERE email = 'ambekardevesh2@gmail.com';

INSERT INTO public.users (id, role, full_name, email, is_active)
SELECT id, 'ADMIN', 'Devesh Ambekar', email, true
FROM auth.users WHERE email = 'ambekardevesh2@gmail.com'
ON CONFLICT (id) DO UPDATE SET role = 'ADMIN', full_name = 'Devesh Ambekar', is_active = true;

-- 8. Federations (Multi-Federation & Super Admin Architecture)
CREATE TABLE IF NOT EXISTS public.federations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'Maharashtra',
    district TEXT NOT NULL,
    city TEXT NOT NULL,
    registration_no TEXT UNIQUE,
    federation_code TEXT UNIQUE,
    contact_phone TEXT,
    contact_email TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.federations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can view active federations" ON public.federations;
CREATE POLICY "Anyone authenticated can view active federations" ON public.federations
    FOR SELECT USING (is_active = true OR public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can manage federations" ON public.federations;
DROP POLICY IF EXISTS "Only super admins can manage federations" ON public.federations;
CREATE POLICY "Only super admins can manage federations" ON public.federations
    FOR ALL USING (public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN'));

INSERT INTO public.federations (id, name, state, district, city, registration_no, federation_code, contact_phone) VALUES
    ('11111111-0000-0000-0000-000000000001', 'Pune District Labour Cooperative Federation', 'Maharashtra', 'Pune', 'Pune', 'MH-PUN-COOP-2018-88', 'MH-PUN-COOP-2018-88', '+91 20 2553 4401'),
    ('22222222-0000-0000-0000-000000000002', 'Nashik District Artisans Cooperative Union', 'Maharashtra', 'Nashik', 'Nashik', 'MH-NSK-COOP-2020-14', 'MH-NSK-COOP-2020-14', '+91 253 257 8820'),
    ('33333333-0000-0000-0000-000000000003', 'Mumbai Metropolitan Labour Federation', 'Maharashtra', 'Mumbai City', 'Mumbai', 'MH-MUM-COOP-2016-09', 'MH-MUM-COOP-2016-09', '+91 22 2261 1140'),
    ('44444444-0000-0000-0000-000000000004', 'Chhatrapati Sambhajinagar Labour Federation', 'Maharashtra', 'Chhatrapati Sambhajinagar', 'Chhatrapati Sambhajinagar', 'MH-CSN-COOP-2021-32', 'MH-CSN-COOP-2021-32', '+91 240 233 4560'),
    ('55555555-0000-0000-0000-000000000005', 'Nagpur District Shramik Cooperative Union', 'Maharashtra', 'Nagpur', 'Nagpur', 'MH-NGP-COOP-2019-55', 'MH-NGP-COOP-2019-55', '+91 712 256 7890'),
    ('66666666-0000-0000-0000-000000000006', 'Hyderabad District Labour Cooperation', 'Telangana', 'Hyderabad', 'Hyderabad', 'TS-HYD-COOP-2022-77', 'TS-HYD-COOP-2022-77', '+91 40 2320 0110')
ON CONFLICT (registration_no) DO UPDATE SET federation_code = EXCLUDED.federation_code;

-- Workers profile & federation link columns
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
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS service_areas TEXT[] DEFAULT '{}';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'Maharashtra';

ALTER TABLE public.addresses ADD COLUMN IF NOT EXISTS district TEXT;

UPDATE public.workers
SET federation_ref_id = '11111111-0000-0000-0000-000000000001'
WHERE federation_ref_id IS NULL;

-- 9. Federation Admin Scope
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

-- 10. Audit Logs
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

DROP POLICY IF EXISTS "Super admins can view all audit logs" ON public.audit_logs;
CREATE POLICY "Super admins can view all audit logs" ON public.audit_logs
    FOR SELECT USING (public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN'));

DROP POLICY IF EXISTS "Admins can insert audit logs" ON public.audit_logs;
CREATE POLICY "Admins can insert audit logs" ON public.audit_logs
    FOR INSERT WITH CHECK (public.auth_user_role() IN ('SUPER_ADMIN', 'ADMIN', 'FEDERATION_ADMIN'));

-- 11. Worker Insurance
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

ALTER TABLE public.worker_insurance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Workers can view own insurance records" ON public.worker_insurance;
CREATE POLICY "Workers can view own insurance records" ON public.worker_insurance
    FOR SELECT USING (auth.uid() = worker_id);

DROP POLICY IF EXISTS "Admins can manage worker insurance records" ON public.worker_insurance;
CREATE POLICY "Admins can manage worker insurance records" ON public.worker_insurance
    FOR ALL USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

-- 12. India States Master Data
CREATE TABLE IF NOT EXISTS public.india_states (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL DEFAULT 'STATE' CHECK (type IN ('STATE', 'UNION_TERRITORY')),
    is_active BOOLEAN DEFAULT true
);

ALTER TABLE public.india_states ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view India states" ON public.india_states;
CREATE POLICY "Anyone can view India states" ON public.india_states
    FOR SELECT USING (true);

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

-- 13. SUPER ADMIN Setup for deveshambekar@gmail.com
UPDATE auth.users 
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email = 'deveshambekar@gmail.com';

INSERT INTO public.users (id, role, full_name, email, is_active)
SELECT id, 'SUPER_ADMIN', COALESCE(raw_user_meta_data->>'full_name', 'Devesh Ambekar'), email, true
FROM auth.users 
WHERE email = 'deveshambekar@gmail.com'
ON CONFLICT (id) DO UPDATE SET role = 'SUPER_ADMIN', full_name = EXCLUDED.full_name, is_active = true;

-- 14. Federation Admin Auth Repair & GoTrue Compatibility
UPDATE auth.users
SET 
    confirmation_token         = COALESCE(confirmation_token, ''),
    recovery_token             = COALESCE(recovery_token, ''),
    email_change               = COALESCE(email_change, ''),
    email_change_token_new     = COALESCE(email_change_token_new, ''),
    email_change_token_current = COALESCE(email_change_token_current, ''),
    phone_change               = COALESCE(phone_change, ''),
    phone_change_token         = COALESCE(phone_change_token, ''),
    reauthentication_token     = COALESCE(reauthentication_token, ''),
    email_confirmed_at         = COALESCE(email_confirmed_at, NOW()),
    raw_app_meta_data          = COALESCE(raw_app_meta_data, '{"provider": "email", "providers": ["email"]}'::jsonb),
    is_sso_user                = COALESCE(is_sso_user, false)
WHERE 
    confirmation_token IS NULL
    OR recovery_token IS NULL
    OR email_change IS NULL
    OR email_change_token_new IS NULL
    OR email_change_token_current IS NULL
    OR phone_change IS NULL
    OR phone_change_token IS NULL
    OR reauthentication_token IS NULL
    OR email_confirmed_at IS NULL;

-- Note: auth.users tokens are explicitly initialized to '' by create_federation_admin.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS requires_password_change BOOLEAN DEFAULT false;

INSERT INTO auth.identities (
    id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
)
SELECT 
    gen_random_uuid(),
    u.id,
    u.id::text,
    jsonb_build_object('sub', u.id::text, 'email', LOWER(TRIM(u.email)), 'email_verified', true, 'phone_verified', false),
    'email',
    NOW(), NOW(), NOW()
FROM auth.users u
WHERE u.email IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM auth.identities i WHERE i.user_id = u.id AND i.provider = 'email'
);

-- Upgraded create_federation_admin stored procedure
CREATE OR REPLACE FUNCTION public.create_federation_admin(
    p_email TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_phone TEXT,
    p_federation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_actor_role TEXT;
    v_caller_id UUID;
    v_encrypted_pw TEXT;
    v_fed_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_actor_role FROM public.users WHERE id = v_caller_id;
        IF v_actor_role IS NOT NULL AND v_actor_role NOT IN ('SUPER_ADMIN', 'ADMIN') THEN
            RAISE EXCEPTION 'Unauthorized: Administrative role required to provision Federation Admins (caller has role: %)', v_actor_role;
        END IF;
    END IF;

    IF p_email IS NULL OR TRIM(p_email) = '' THEN
        RAISE EXCEPTION 'Admin email is required';
    END IF;
    IF p_password IS NULL OR length(p_password) < 6 THEN
        RAISE EXCEPTION 'Password must be at least 6 characters';
    END IF;

    SELECT name INTO v_fed_name FROM public.federations WHERE id = p_federation_id;
    IF v_fed_name IS NULL THEN
        RAISE EXCEPTION 'Federation not found with ID: %', p_federation_id;
    END IF;

    SELECT id INTO v_user_id FROM auth.users WHERE LOWER(email) = LOWER(TRIM(p_email));
    v_encrypted_pw := crypt(p_password, gen_salt('bf'));

    IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();

        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
            confirmation_token, recovery_token, email_change, email_change_token_new,
            email_change_token_current, phone_change, phone_change_token, reauthentication_token,
            raw_app_meta_data, raw_user_meta_data, is_sso_user, created_at, updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated',
            LOWER(TRIM(p_email)), v_encrypted_pw, NOW(),
            '', '', '', '', '', '', '', '',
            '{"provider": "email", "providers": ["email"]}'::jsonb,
            jsonb_build_object('full_name', p_full_name, 'phone', p_phone, 'role', 'FEDERATION_ADMIN', 'federation_id', p_federation_id, 'requires_password_change', true),
            false, NOW(), NOW()
        );

        INSERT INTO auth.identities (
            id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
        ) VALUES (
            gen_random_uuid(), v_user_id, v_user_id::text,
            jsonb_build_object('sub', v_user_id::text, 'email', LOWER(TRIM(p_email)), 'email_verified', true, 'phone_verified', false),
            'email', NOW(), NOW(), NOW()
        );
    ELSE
        UPDATE auth.users
        SET encrypted_password         = v_encrypted_pw,
            email_confirmed_at         = COALESCE(email_confirmed_at, NOW()),
            confirmation_token         = COALESCE(confirmation_token, ''),
            recovery_token             = COALESCE(recovery_token, ''),
            email_change               = COALESCE(email_change, ''),
            email_change_token_new     = COALESCE(email_change_token_new, ''),
            email_change_token_current = COALESCE(email_change_token_current, ''),
            phone_change               = COALESCE(phone_change, ''),
            phone_change_token         = COALESCE(phone_change_token, ''),
            reauthentication_token     = COALESCE(reauthentication_token, ''),
            raw_app_meta_data          = COALESCE(raw_app_meta_data, '{"provider": "email", "providers": ["email"]}'::jsonb),
            is_sso_user                = COALESCE(is_sso_user, false),
            raw_user_meta_data         = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('full_name', p_full_name, 'phone', p_phone, 'role', 'FEDERATION_ADMIN', 'federation_id', p_federation_id, 'requires_password_change', true),
            updated_at                 = NOW()
        WHERE id = v_user_id;

        INSERT INTO auth.identities (
            id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
        ) VALUES (
            gen_random_uuid(), v_user_id, v_user_id::text,
            jsonb_build_object('sub', v_user_id::text, 'email', LOWER(TRIM(p_email)), 'email_verified', true, 'phone_verified', false),
            'email', NOW(), NOW(), NOW()
        )
        ON CONFLICT (provider_id, provider) DO UPDATE
        SET identity_data = jsonb_build_object('sub', v_user_id::text, 'email', LOWER(TRIM(p_email)), 'email_verified', true, 'phone_verified', false),
            updated_at = NOW();
    END IF;

    INSERT INTO public.users (id, email, phone, role, full_name, is_active, requires_password_change)
    VALUES (v_user_id, LOWER(TRIM(p_email)), p_phone, 'FEDERATION_ADMIN', p_full_name, true, true)
    ON CONFLICT (id) DO UPDATE
    SET role = 'FEDERATION_ADMIN', full_name = EXCLUDED.full_name, phone = COALESCE(EXCLUDED.phone, public.users.phone), is_active = true, requires_password_change = true;

    INSERT INTO public.admin_federation_scope (user_id, federation_id, scope_level, assigned_by, is_active)
    VALUES (v_user_id, p_federation_id, 'FEDERATION', v_caller_id, true)
    ON CONFLICT (user_id, federation_id) DO UPDATE
    SET is_active = true, scope_level = 'FEDERATION', assigned_by = COALESCE(v_caller_id, admin_federation_scope.assigned_by), assigned_at = NOW();

    RETURN jsonb_build_object('success', true, 'user_id', v_user_id, 'email', LOWER(TRIM(p_email)), 'federation_id', p_federation_id, 'federation_name', v_fed_name);
END;
$$;

-- 16. Booking & Verification RLS Policies (Repair & Complete Scope)
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

DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
CREATE POLICY "Admins can view all users"
ON public.users FOR SELECT
USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can view verification history" ON public.worker_verification_history;
CREATE POLICY "Admins can view verification history"
ON public.worker_verification_history FOR SELECT
USING (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can insert verification history" ON public.worker_verification_history;
CREATE POLICY "Admins can insert verification history"
ON public.worker_verification_history FOR INSERT
WITH CHECK (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Admins can insert verification documents" ON public.worker_verification_documents;
CREATE POLICY "Admins can insert verification documents"
ON public.worker_verification_documents FOR INSERT
WITH CHECK (public.auth_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'FEDERATION_ADMIN'));

DROP POLICY IF EXISTS "Workers can view customer address for their bookings" ON public.addresses;
CREATE POLICY "Workers can view customer address for their bookings" ON public.addresses
FOR SELECT USING (
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

-- 17. Booking Payment Method & FairMatch 3.5km Operational Radius
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'RAZORPAY';
CREATE INDEX IF NOT EXISTS idx_bookings_payment_method ON public.bookings(payment_method);

CREATE OR REPLACE FUNCTION public.fairmatch_recommend_workers(
  p_service_id UUID,
  p_customer_lat NUMERIC DEFAULT NULL,
  p_customer_lng NUMERIC DEFAULT NULL,
  p_weights JSONB DEFAULT NULL,
  p_limit INTEGER DEFAULT 10,
  p_algorithm TEXT DEFAULT 'fairmatch_v1'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_start_time TIMESTAMPTZ := clock_timestamp();
  v_w_skill NUMERIC := 0.35;
  v_w_dist NUMERIC := 0.20;
  v_w_avail NUMERIC := 0.15;
  v_w_rating NUMERIC := 0.10;
  v_w_exp NUMERIC := 0.10;
  v_w_fairness NUMERIC := 0.10;
  v_effective_weights JSONB;
  v_candidates RECORD;
  v_worker_list JSONB := '[]'::jsonb;
  v_top_worker_ids JSONB := '[]'::jsonb;
  v_candidate_count INTEGER := 0;
  v_exec_ms INTEGER := 0;
BEGIN
  IF p_algorithm = 'nearest' THEN
    v_w_skill := 0.0; v_w_dist := 1.0; v_w_avail := 0.0;
    v_w_rating := 0.0; v_w_exp := 0.0; v_w_fairness := 0.0;
  ELSIF p_algorithm = 'highest_rated' THEN
    v_w_skill := 0.0; v_w_dist := 0.0; v_w_avail := 0.0;
    v_w_rating := 1.0; v_w_exp := 0.0; v_w_fairness := 0.0;
  ELSIF p_algorithm = 'rating_distance' THEN
    v_w_skill := 0.0; v_w_dist := 0.5; v_w_avail := 0.0;
    v_w_rating := 0.5; v_w_exp := 0.0; v_w_fairness := 0.0;
  ELSIF p_weights IS NOT NULL THEN
    v_w_skill := COALESCE((p_weights->>'skill')::numeric, v_w_skill);
    v_w_dist := COALESCE((p_weights->>'distance')::numeric, v_w_dist);
    v_w_avail := COALESCE((p_weights->>'availability')::numeric, v_w_avail);
    v_w_rating := COALESCE((p_weights->>'rating')::numeric, v_w_rating);
    v_w_exp := COALESCE((p_weights->>'experience')::numeric, v_w_exp);
    v_w_fairness := COALESCE((p_weights->>'fairness')::numeric, v_w_fairness);
  END IF;

  v_effective_weights := jsonb_build_object(
    'skill', v_w_skill,
    'distance', v_w_dist,
    'availability', v_w_avail,
    'rating', v_w_rating,
    'experience', v_w_exp,
    'fairness', v_w_fairness
  );

  WITH eligible_candidates AS (
    SELECT 
      w.id AS worker_id,
      u.full_name,
      u.avatar_url,
      COALESCE(w.rating, 0.0) AS rating,
      COALESCE(w.review_count, 0) AS review_count,
      COALESCE(w.completed_jobs, 0) AS completed_jobs,
      COALESCE(w.experience_years, 1) AS experience_years,
      COALESCE(w.location_tag, 'Pune Area') AS location_tag,
      w.bio,
      w.latitude,
      w.longitude,
      w.is_union_gold,
      w.is_coop_master,
      COALESCE(
        public.calculate_haversine_distance(p_customer_lat, p_customer_lng, w.latitude, w.longitude),
        1.5
      ) AS distance_km,
      (w.latitude IS NOT NULL AND p_customer_lat IS NOT NULL) AS has_coordinates,
      COALESCE((
        SELECT COUNT(*)::int 
        FROM public.bookings b
        WHERE b.worker_id = w.id 
          AND b.status IN ('accepted', 'onTheWay', 'arrived', 'inProgress')
      ), 0) AS active_bookings_count,
      COALESCE((
        SELECT COUNT(*)::int 
        FROM public.bookings b
        WHERE b.worker_id = w.id 
          AND b.status = 'completed'
          AND b.created_at >= (NOW() - INTERVAL '7 days')
      ), 0) AS recent_7d_bookings_count
    FROM public.workers w
    INNER JOIN public.users u ON u.id = w.id
    INNER JOIN public.worker_skills ws ON ws.worker_id = w.id AND ws.skill_id = p_service_id
    WHERE w.worker_status = 'ACTIVE'
      AND w.is_available = true
  ),
  scored_candidates AS (
    SELECT 
      c.*,
      1.0::numeric AS skill_score,
      -- Distance score: normalized to 3.5 km ward radius
      CASE 
        WHEN c.has_coordinates THEN GREATEST(0.0, ROUND((1.0 - (c.distance_km / 3.5))::numeric, 4))
        ELSE 0.5::numeric
      END AS distance_score,
      1.0::numeric AS availability_score,
      CASE 
        WHEN c.review_count > 0 THEN GREATEST(0.0, LEAST(1.0, ROUND(((c.rating - 1.0) / 4.0)::numeric, 4)))
        ELSE 0.5::numeric
      END AS rating_score,
      GREATEST(0.0, LEAST(1.0, ROUND((c.experience_years::numeric / 10.0), 4))) AS experience_score,
      GREATEST(0.0, ROUND((1.0 - (LEAST(10.0, (c.active_bookings_count * 2.0 + c.recent_7d_bookings_count)::numeric) / 10.0))::numeric, 4)) AS fairness_score
    FROM eligible_candidates c
  ),
  ranked_candidates AS (
    SELECT 
      s.*,
      ROUND(
        (v_w_skill * s.skill_score +
         v_w_dist * s.distance_score +
         v_w_avail * s.availability_score +
         v_w_rating * s.rating_score +
         v_w_exp * s.experience_score +
         v_w_fairness * s.fairness_score)::numeric,
        4
      ) AS total_score,
      ARRAY_REMOVE(ARRAY[
        'Verified Skill',
        'Available Now',
        CASE WHEN s.distance_km <= 3.5 THEN 'Within 3.5 km Ward' 
             WHEN s.distance_score >= 0.6 THEN 'Nearby' ELSE NULL END,
        CASE WHEN s.rating >= 4.5 AND s.review_count >= 1 THEN 'Top Rated' 
             WHEN s.rating_score >= 0.6 THEN 'Good Rating' ELSE NULL END,
        CASE WHEN s.experience_years >= 8 THEN 'Veteran Artisan' 
             WHEN s.experience_years >= 4 THEN 'Experienced' ELSE NULL END,
        CASE WHEN s.fairness_score >= 0.7 THEN 'Cooperative Partner' ELSE NULL END
      ], NULL) AS explanation_tags
    FROM scored_candidates s
  )
  SELECT 
    COUNT(*)::int,
    jsonb_agg(
      jsonb_build_object(
        'id', r.worker_id,
        'name', r.full_name,
        'avatar_url', r.avatar_url,
        'rating', r.rating,
        'review_count', r.review_count,
        'completed_jobs', r.completed_jobs,
        'experience_years', r.experience_years,
        'distance_km', r.distance_km,
        'location_tag', r.location_tag,
        'bio', r.bio,
        'is_union_gold', r.is_union_gold,
        'is_coop_master', r.is_coop_master,
        'skill_score', r.skill_score,
        'distance_score', r.distance_score,
        'availability_score', r.availability_score,
        'rating_score', r.rating_score,
        'experience_score', r.experience_score,
        'fairness_score', r.fairness_score,
        'workload_score', r.fairness_score,
        'active_bookings', r.active_bookings_count,
        'recent_7d_bookings', r.recent_7d_bookings_count,
        'total_score', r.total_score,
        'explanation_tags', r.explanation_tags
      )
      ORDER BY 
        r.total_score DESC,
        r.completed_jobs ASC,
        r.experience_years DESC,
        r.worker_id ASC
    )
  INTO v_candidate_count, v_worker_list
  FROM (
    SELECT * FROM ranked_candidates 
    ORDER BY total_score DESC, completed_jobs ASC, experience_years DESC, worker_id ASC 
    LIMIT p_limit
  ) r;

  v_worker_list := COALESCE(v_worker_list, '[]'::jsonb);

  SELECT COALESCE(jsonb_agg(elem->'id'), '[]'::jsonb)
  INTO v_top_worker_ids
  FROM jsonb_array_elements(v_worker_list) AS elem;

  v_exec_ms := ROUND((EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000))::int;

  INSERT INTO public.fairmatch_logs (
    requested_service_id,
    customer_id,
    algorithm_version,
    weights,
    candidate_count,
    top_worker_ids,
    execution_time_ms
  ) VALUES (
    p_service_id,
    auth.uid(),
    p_algorithm,
    v_effective_weights,
    v_candidate_count,
    v_top_worker_ids,
    v_exec_ms
  );

  RETURN jsonb_build_object(
    'success', true,
    'algorithm', p_algorithm,
    'total_candidates', v_candidate_count,
    'execution_time_ms', v_exec_ms,
    'weights', v_effective_weights,
    'operational_radius_km', 3.5,
    'workers', v_worker_list
  );
END;
$func$;



