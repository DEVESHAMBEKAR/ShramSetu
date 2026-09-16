-- Migration 015: Security & Performance Hardening
-- Hardens search_path on critical SECURITY DEFINER functions to mitigate schema hijacking.
-- Adds composite performance indexes for high-frequency queries in discovery, demand forecasting, payments, and realtime tracking.

-- ============================================================================
-- 1. SECURITY DEFINER SEARCH PATH HARDENING
-- ============================================================================

-- 1.1 Patch auth_user_role() with explicit search_path
-- Used across all RLS policies and admin RPCs. Setting search_path prevents
-- search_path injection attacks in SECURITY DEFINER context.
CREATE OR REPLACE FUNCTION public.auth_user_role() RETURNS TEXT AS $$
  SELECT role FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER
SET search_path = public, pg_temp;

-- 1.2 Patch update_worker_rating_and_count() with explicit search_path
-- Trigger executed on review insert/update/delete.
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
$func$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- ============================================================================
-- 2. COMPOSITE PERFORMANCE INDEXES
-- ============================================================================

-- 2.1 Optimize historical demand forecasting aggregation
-- Used by get_historical_booking_demand RPC when filtering by service and date
CREATE INDEX IF NOT EXISTS idx_bookings_demand_agg 
  ON public.bookings (service_id, scheduled_date, status);

-- 2.2 Optimize worker discovery and FairMatch candidate filtering
-- Used in candidate queries filtering by active status and availability
CREATE INDEX IF NOT EXISTS idx_workers_status_avail 
  ON public.workers (worker_status, is_available);

-- 2.3 Optimize payment lookups by booking and status (escrow tracking)
CREATE INDEX IF NOT EXISTS idx_payments_booking_status 
  ON public.payments (booking_id, status);

-- 2.4 Optimize FairMatch analytics and audit trail ordering
CREATE INDEX IF NOT EXISTS idx_fairmatch_logs_created 
  ON public.fairmatch_logs (created_at DESC);

-- 2.5 Optimize customer bookings listing by status
CREATE INDEX IF NOT EXISTS idx_bookings_customer_status 
  ON public.bookings (customer_id, status);

-- 2.6 Optimize worker jobs listing by status
CREATE INDEX IF NOT EXISTS idx_bookings_worker_status 
  ON public.bookings (worker_id, status);

-- 2.7 Optimize customer address retrieval
CREATE INDEX IF NOT EXISTS idx_addresses_user_id 
  ON public.addresses (user_id);
