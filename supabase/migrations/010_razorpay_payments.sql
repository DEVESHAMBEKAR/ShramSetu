-- Migration 010: Razorpay Payment + Escrow Architecture
-- Adds Razorpay integration fields and escrow state to payments table

-- 1. Add amount_paise (integer paise - authoritative, avoids float math)
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS amount_paise INTEGER;

-- 2. Razorpay order/payment/signature fields
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS razorpay_order_id TEXT,
  ADD COLUMN IF NOT EXISTS razorpay_payment_id TEXT,
  ADD COLUMN IF NOT EXISTS razorpay_signature TEXT;

-- 3. Escrow status (separate from payment status)
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS escrow_status TEXT NOT NULL DEFAULT ''not_funded''
    CHECK (escrow_status IN (''not_funded'', ''held'', ''release_pending'', ''released'', ''refund_pending'', ''refunded''));

-- 4. Recreate payment status CHECK to add CANCELLED
ALTER TABLE public.payments DROP CONSTRAINT IF EXISTS payments_status_check;
ALTER TABLE public.payments
  ADD CONSTRAINT payments_status_check
    CHECK (status IN (''PENDING'', ''PAID'', ''FAILED'', ''REFUNDED'', ''CANCELLED''));

-- 5. Idempotency constraints
ALTER TABLE public.payments
  ADD CONSTRAINT IF NOT EXISTS payments_booking_id_unique UNIQUE (booking_id);

CREATE UNIQUE INDEX IF NOT EXISTS payments_razorpay_order_id_unique
  ON public.payments (razorpay_order_id)
  WHERE razorpay_order_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS payments_razorpay_payment_id_unique
  ON public.payments (razorpay_payment_id)
  WHERE razorpay_payment_id IS NOT NULL;

-- 6. Performance indexes
CREATE INDEX IF NOT EXISTS idx_payments_escrow_status ON public.payments (escrow_status);
CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON public.payments (customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_worker_id ON public.payments (worker_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments (status);

-- 7. INSERT policy for customers
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = ''payments'' AND policyname = ''Customers can insert their own payments''
  ) THEN
    CREATE POLICY "Customers can insert their own payments"
      ON public.payments FOR INSERT
      WITH CHECK (auth.uid() = customer_id);
  END IF;
END $$;

-- 8. RPC: release_escrow_for_booking (SECURITY DEFINER — bypasses RLS)
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
  SELECT * INTO v_payment FROM public.payments
    WHERE booking_id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(''success'', false, ''error'', ''Payment not found'');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
  IF v_booking.status != ''completed'' THEN
    RETURN jsonb_build_object(''success'', false, ''error'', ''Booking not completed'');
  END IF;

  IF v_payment.escrow_status != ''held'' THEN
    RETURN jsonb_build_object(''success'', false, ''error'', ''Escrow not in held state: '' || v_payment.escrow_status);
  END IF;

  UPDATE public.payments SET escrow_status = ''released'', updated_at = NOW()
    WHERE booking_id = p_booking_id;

  UPDATE public.workers SET completed_jobs = completed_jobs + 1, updated_at = NOW()
    WHERE id = v_payment.worker_id;

  RETURN jsonb_build_object(''success'', true, ''released_amount'', v_payment.amount);
END;
$func$;

-- 9. RPC: create_payment_record (atomic insert for Edge Function)
CREATE OR REPLACE FUNCTION public.create_payment_record(
  p_booking_id UUID, p_customer_id UUID, p_worker_id UUID,
  p_amount NUMERIC, p_amount_paise INTEGER, p_razorpay_order_id TEXT,
  p_payment_method TEXT DEFAULT ''razorpay''
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_payment_id UUID;
BEGIN
  INSERT INTO public.payments (
    booking_id, customer_id, worker_id, amount, amount_paise,
    status, escrow_status, razorpay_order_id, payment_method
  )
  VALUES (
    p_booking_id, p_customer_id, p_worker_id, p_amount, p_amount_paise,
    ''PENDING'', ''not_funded'', p_razorpay_order_id, p_payment_method
  )
  ON CONFLICT (booking_id) DO UPDATE
    SET razorpay_order_id = EXCLUDED.razorpay_order_id, updated_at = NOW()
  RETURNING id INTO v_payment_id;
  RETURN v_payment_id;
END;
$func$;

-- 10. RPC: record_payment_verification (atomic, idempotent)
CREATE OR REPLACE FUNCTION public.record_payment_verification(
  p_booking_id UUID, p_razorpay_order_id TEXT,
  p_razorpay_payment_id TEXT, p_razorpay_signature TEXT, p_verified BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_payment RECORD;
BEGIN
  SELECT * INTO v_payment FROM public.payments
    WHERE booking_id = p_booking_id AND razorpay_order_id = p_razorpay_order_id
    FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(''success'', false, ''error'', ''Payment record not found'');
  END IF;

  -- Idempotency: already PAID for same payment ID → success
  IF v_payment.status = ''PAID'' AND v_payment.razorpay_payment_id = p_razorpay_payment_id THEN
    RETURN jsonb_build_object(''success'', true, ''idempotent'', true);
  END IF;

  IF p_verified THEN
    UPDATE public.payments SET
      status = ''PAID'', escrow_status = ''held'',
      razorpay_payment_id = p_razorpay_payment_id,
      razorpay_signature = p_razorpay_signature,
      updated_at = NOW()
    WHERE booking_id = p_booking_id;
  ELSE
    UPDATE public.payments SET status = ''FAILED'', updated_at = NOW()
    WHERE booking_id = p_booking_id;
  END IF;

  RETURN jsonb_build_object(''success'', true, ''verified'', p_verified);
END;
$func$;
