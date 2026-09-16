-- Migration 011: Reviews, Ratings & Worker Reputation Architecture
-- Adds updated_at to reviews, review_count to workers, automatic aggregation trigger, secure review RPC, and strengthened RLS.

-- 1. Add updated_at column to reviews if not exists
ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 2. Add review_count column to workers if not exists
ALTER TABLE public.workers
  ADD COLUMN IF NOT EXISTS review_count INTEGER NOT NULL DEFAULT 0;

-- 3. Performance indexes
CREATE INDEX IF NOT EXISTS idx_reviews_worker_id ON public.reviews (worker_id);
CREATE INDEX IF NOT EXISTS idx_reviews_customer_id ON public.reviews (customer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON public.reviews (created_at DESC);

-- 4. Trigger Function: Atomically recalculate worker rating and review count
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

-- Drop trigger if already exists and recreate
DROP TRIGGER IF EXISTS trg_update_worker_rating ON public.reviews;
CREATE TRIGGER trg_update_worker_rating
AFTER INSERT OR UPDATE OR DELETE ON public.reviews
FOR EACH ROW
EXECUTE FUNCTION public.update_worker_rating_and_count();

-- 5. Secure RPC: submit_booking_review
-- Server-side validation: caller identity, booking ownership, completed status,
-- authoritative worker_id derivation from booking, rating validation, and duplicate prevention.
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

  -- Validate rating
  IF p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rating must be between 1 and 5');
  END IF;

  -- Verify booking ownership and status
  SELECT worker_id, status INTO v_worker_id, v_booking_status
  FROM public.bookings
  WHERE id = p_booking_id AND customer_id = v_customer_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or does not belong to you');
  END IF;

  IF v_booking_status != 'completed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only completed bookings can be reviewed');
  END IF;

  IF v_worker_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No worker assigned to this booking');
  END IF;

  -- Check if review already exists for this booking (support idempotent update if owned)
  SELECT id INTO v_existing FROM public.reviews WHERE booking_id = p_booking_id;
  IF FOUND THEN
    -- Update existing review (owner editing rating/comment)
    UPDATE public.reviews
    SET rating = p_rating,
        comment = TRIM(p_comment),
        updated_at = NOW()
    WHERE id = v_existing.id
    RETURNING id, created_at INTO v_review_id, v_created_at;

    RETURN jsonb_build_object(
      'success', true,
      'review_id', v_review_id,
      'booking_id', p_booking_id,
      'worker_id', v_worker_id,
      'customer_id', v_customer_id,
      'rating', p_rating,
      'comment', TRIM(p_comment),
      'created_at', v_created_at,
      'is_update', true
    );
  END IF;

  -- Insert new review
  INSERT INTO public.reviews (
    booking_id,
    customer_id,
    worker_id,
    rating,
    comment,
    created_at,
    updated_at
  )
  VALUES (
    p_booking_id,
    v_customer_id,
    v_worker_id,
    p_rating,
    TRIM(p_comment),
    NOW(),
    NOW()
  )
  RETURNING id, created_at INTO v_review_id, v_created_at;

  RETURN jsonb_build_object(
    'success', true,
    'review_id', v_review_id,
    'booking_id', p_booking_id,
    'worker_id', v_worker_id,
    'customer_id', v_customer_id,
    'rating', p_rating,
    'comment', TRIM(p_comment),
    'created_at', v_created_at,
    'is_update', false
  );
END;
$func$;

-- 6. RPC: get_worker_rating_summary
CREATE OR REPLACE FUNCTION public.get_worker_rating_summary(p_worker_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $func$
  SELECT jsonb_build_object(
    'worker_id', p_worker_id,
    'average_rating', COALESCE(ROUND(AVG(rating)::numeric, 2), 0.0),
    'review_count', COUNT(*)::int,
    'five_star_count', COUNT(*) FILTER (WHERE rating = 5)::int,
    'four_star_count', COUNT(*) FILTER (WHERE rating = 4)::int,
    'three_star_count', COUNT(*) FILTER (WHERE rating = 3)::int,
    'two_star_count', COUNT(*) FILTER (WHERE rating = 2)::int,
    'one_star_count', COUNT(*) FILTER (WHERE rating = 1)::int
  )
  FROM public.reviews
  WHERE worker_id = p_worker_id;
$func$;

-- 7. Strengthened RLS Policies
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view reviews" ON public.reviews;
CREATE POLICY "Anyone can view reviews" ON public.reviews FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Customers can create reviews for their bookings" ON public.reviews;
CREATE POLICY "Customers can create reviews for their bookings" ON public.reviews FOR INSERT
  WITH CHECK (
    auth.uid() = customer_id AND
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_id
        AND b.customer_id = auth.uid()
        AND b.worker_id = reviews.worker_id
        AND b.status = 'completed'
    )
  );

DROP POLICY IF EXISTS "Customers can update their own reviews" ON public.reviews;
CREATE POLICY "Customers can update their own reviews" ON public.reviews FOR UPDATE
  USING (auth.uid() = customer_id)
  WITH CHECK (auth.uid() = customer_id);

DROP POLICY IF EXISTS "Admins can manage reviews" ON public.reviews;
CREATE POLICY "Admins can manage reviews" ON public.reviews FOR ALL
  USING (auth_user_role() = 'ADMIN');