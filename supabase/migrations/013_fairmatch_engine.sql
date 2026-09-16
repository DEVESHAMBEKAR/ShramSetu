-- Migration 013: FairMatch Worker Matching & Ranking Architecture
-- Implements transparent, explainable multi-factor scoring, deterministic tie-breaking,
-- server-side workload aggregation under RLS, and research audit logging.

-- 1. Performance Indexes for Matching & Workload Queries
CREATE INDEX IF NOT EXISTS idx_bookings_worker_status_created 
  ON public.bookings (worker_id, status, created_at);

CREATE INDEX IF NOT EXISTS idx_worker_skills_skill_worker 
  ON public.worker_skills (skill_id, worker_id);

-- 2. FairMatch Research Logging Table
-- Strictly omits customer PII, addresses, phone numbers, coordinates, or payment secrets.
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

CREATE INDEX IF NOT EXISTS idx_fairmatch_logs_service ON public.fairmatch_logs(requested_service_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fairmatch_logs_algo ON public.fairmatch_logs(algorithm_version);

-- 3. RLS for FairMatch Logs
ALTER TABLE public.fairmatch_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view FairMatch logs" ON public.fairmatch_logs;
CREATE POLICY "Admins can view FairMatch logs" ON public.fairmatch_logs FOR SELECT
  USING (auth_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "Authenticated users can record FairMatch logs" ON public.fairmatch_logs;
CREATE POLICY "Authenticated users can record FairMatch logs" ON public.fairmatch_logs FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- 4. Haversine Distance Helper in SQL
CREATE OR REPLACE FUNCTION public.calculate_haversine_distance(
  lat1 NUMERIC,
  lon1 NUMERIC,
  lat2 NUMERIC,
  lon2 NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
  v_earth_radius NUMERIC := 6371.0; -- Earth's radius in kilometers
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

  v_a := sin(v_dlat / 2.0) ^ 2.0 +
         cos(radians(lat1)) * cos(radians(lat2)) *
         sin(v_dlon / 2.0) ^ 2.0;

  v_c := 2.0 * atan2(sqrt(v_a), sqrt(GREATEST(0.0, 1.0 - v_a)));

  RETURN ROUND((v_earth_radius * v_c)::numeric, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 5. Secure FairMatch Scoring & Ranking RPC: fairmatch_recommend_workers
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
  -- Configure weights based on requested algorithm / custom weights
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

  -- Common table expression:
  -- 1. Filter eligible workers (active, available, possessed verified skill)
  -- 2. Aggregate server-side workload (active + 7-day bookings)
  -- 3. Calculate normalized factors
  -- 4. Compute weighted score
  -- 5. Deterministic tie-breaking
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
      -- Geodesic distance calculation
      COALESCE(
        public.calculate_haversine_distance(p_customer_lat, p_customer_lng, w.latitude, w.longitude),
        2.0
      ) AS distance_km,
      (w.latitude IS NOT NULL AND p_customer_lat IS NOT NULL) AS has_coordinates,
      -- Server-side workload aggregation
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
      -- 1. Skill Score: 1.0 (exact verified skill match verified via inner join)
      1.0::numeric AS skill_score,
      -- 2. Distance Score: max(0.0, 1.0 - (d / 15.0)). Fallback to 0.5 if coordinates absent.
      CASE 
        WHEN c.has_coordinates THEN GREATEST(0.0, ROUND((1.0 - (c.distance_km / 15.0))::numeric, 4))
        ELSE 0.5::numeric
      END AS distance_score,
      -- 3. Availability Score: 1.0 (verified available)
      1.0::numeric AS availability_score,
      -- 4. Rating Score: (rating - 1.0) / 4.0. Cold-start neutral baseline: 0.5 when review_count == 0.
      CASE 
        WHEN c.review_count > 0 THEN GREATEST(0.0, LEAST(1.0, ROUND(((c.rating - 1.0) / 4.0)::numeric, 4)))
        ELSE 0.5::numeric
      END AS rating_score,
      -- 5. Experience Score: min(1.0, experience / 10.0)
      GREATEST(0.0, LEAST(1.0, ROUND((c.experience_years::numeric / 10.0), 4))) AS experience_score,
      -- 6. Fairness / Workload Score: Saturation at 10. W = (2 * active) + recent_7d.
      GREATEST(0.0, ROUND((1.0 - (LEAST(10.0, (c.active_bookings_count * 2.0 + c.recent_7d_bookings_count)::numeric) / 10.0))::numeric, 4)) AS fairness_score
    FROM eligible_candidates c
  ),
  ranked_candidates AS (
    SELECT 
      s.*,
      -- Total FairMatch Weighted Score
      ROUND(
        (v_w_skill * s.skill_score +
         v_w_dist * s.distance_score +
         v_w_avail * s.availability_score +
         v_w_rating * s.rating_score +
         v_w_exp * s.experience_score +
         v_w_fairness * s.fairness_score)::numeric,
        4
      ) AS total_score,
      -- Human-readable explainability reason tags
      ARRAY_REMOVE(ARRAY[
        'Verified Skill',
        'Available Now',
        CASE WHEN s.distance_score >= 0.6 THEN 'Nearby' ELSE NULL END,
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
        'total_score', r.total_score,
        'skill_score', r.skill_score,
        'distance_score', r.distance_score,
        'availability_score', r.availability_score,
        'rating_score', r.rating_score,
        'experience_score', r.experience_score,
        'fairness_score', r.fairness_score,
        'explanation_tags', to_jsonb(r.explanation_tags)
      )
      -- Deterministic tie-breaking:
      -- 1. Total score DESC
      -- 2. Skill score DESC
      -- 3. Distance ASC
      -- 4. Worker UUID ASC (stable deterministic order)
      ORDER BY r.total_score DESC, r.skill_score DESC, r.distance_km ASC, r.worker_id ASC
    )
  INTO v_candidate_count, v_worker_list
  FROM (
    SELECT * FROM ranked_candidates 
    ORDER BY total_score DESC, skill_score DESC, distance_km ASC, worker_id ASC 
    LIMIT p_limit
  ) r;

  -- Default to empty list if no eligible candidates found
  v_worker_list := COALESCE(v_worker_list, '[]'::jsonb);
  v_candidate_count := COALESCE(v_candidate_count, 0);

  -- Extract top worker IDs for audit log
  SELECT COALESCE(jsonb_agg(w->>'id'), '[]'::jsonb)
  INTO v_top_worker_ids
  FROM jsonb_array_elements(v_worker_list) w;

  v_exec_ms := (EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000)::int;

  -- Record research audit log (non-blocking)
  BEGIN
    INSERT INTO public.fairmatch_logs (
      requested_service_id,
      customer_id,
      algorithm_version,
      weights,
      candidate_count,
      top_worker_ids,
      execution_time_ms,
      created_at
    )
    VALUES (
      p_service_id,
      auth.uid(),
      COALESCE(p_algorithm, 'fairmatch_v1'),
      v_effective_weights,
      v_candidate_count,
      v_top_worker_ids,
      v_exec_ms,
      NOW()
    );
  EXCEPTION WHEN OTHERS THEN
    -- Logging failure never blocks matching recommendation
    NULL;
  END;

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