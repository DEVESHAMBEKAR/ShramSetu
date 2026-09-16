-- Migration 014: AI-Based Demand Forecasting Architecture
-- Implements demand_forecasts persistence table, performance indexes,
-- RLS policies restricted to Admin, and server-side aggregation RPCs.

-- 1. Demand Forecasts Table
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

-- 2. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_demand_forecasts_service_date 
  ON public.demand_forecasts (service_id, forecast_date);

CREATE INDEX IF NOT EXISTS idx_demand_forecasts_location_date 
  ON public.demand_forecasts (location_key, forecast_date);

CREATE INDEX IF NOT EXISTS idx_demand_forecasts_model_version 
  ON public.demand_forecasts (model_version);

-- 3. Row Level Security
ALTER TABLE public.demand_forecasts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view demand forecasts" ON public.demand_forecasts;
CREATE POLICY "Admins can view demand forecasts" ON public.demand_forecasts FOR SELECT
  USING (auth_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "Admins can insert and update demand forecasts" ON public.demand_forecasts;
CREATE POLICY "Admins can insert and update demand forecasts" ON public.demand_forecasts FOR ALL
  USING (auth_user_role() = 'ADMIN');

-- 4. Server-Side Historical Booking Aggregation RPC
-- Aggregates completed, in-progress, accepted, and pending bookings by day, service, and location.
-- Zero exposure of customer PII, phone numbers, or private addresses.
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
  -- Restrict access to authenticated admins
  IF auth_user_role() <> 'ADMIN' THEN
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

-- 5. Batch Save Demand Forecasts RPC
CREATE OR REPLACE FUNCTION public.save_demand_forecasts(
  p_forecasts JSONB
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item JSONB;
  v_count INTEGER := 0;
BEGIN
  IF auth_user_role() <> 'ADMIN' THEN
    RAISE EXCEPTION 'Unauthorized: Only federation administrators can persist forecast models.';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_forecasts)
  LOOP
    INSERT INTO public.demand_forecasts (
      service_id,
      service_name,
      location_key,
      forecast_date,
      predicted_demand,
      lower_bound,
      upper_bound,
      model_version,
      horizon_days,
      data_source,
      metadata,
      generated_at
    ) VALUES (
      (v_item->>'service_id')::uuid,
      v_item->>'service_name',
      COALESCE(v_item->>'location_key', 'All'),
      (v_item->>'forecast_date')::date,
      (v_item->>'predicted_demand')::numeric,
      (v_item->>'lower_bound')::numeric,
      (v_item->>'upper_bound')::numeric,
      COALESCE(v_item->>'model_version', 'demand_forecast_v1'),
      COALESCE((v_item->>'horizon_days')::integer, 7),
      COALESCE(v_item->>'data_source', 'live'),
      COALESCE(v_item->'metadata', '{}'::jsonb),
      COALESCE((v_item->>'generated_at')::timestamptz, NOW())
    )
    ON CONFLICT (service_id, location_key, forecast_date, model_version, data_source)
    DO UPDATE SET
      predicted_demand = EXCLUDED.predicted_demand,
      lower_bound = EXCLUDED.lower_bound,
      upper_bound = EXCLUDED.upper_bound,
      horizon_days = EXCLUDED.horizon_days,
      metadata = EXCLUDED.metadata,
      generated_at = EXCLUDED.generated_at,
      created_at = NOW();

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;
