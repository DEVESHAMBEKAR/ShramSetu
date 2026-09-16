-- Migration 012: Device Tokens & Push Notifications Architecture
-- Supports multi-device FCM tokens, persistent in-app notifications, and secure token lifecycle.

-- 1. Create user_device_tokens table
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

CREATE INDEX IF NOT EXISTS idx_user_device_tokens_user ON public.user_device_tokens(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_user_device_tokens_token ON public.user_device_tokens(fcm_token);

-- 2. Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- 'booking_status', 'payment_status', 'review_received', etc.
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}'::jsonb,
  read_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.notifications(recipient_user_id) WHERE read_at IS NULL;

-- 3. Secure RPC: register_device_token
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

  IF p_fcm_token IS NULL OR TRIM(p_fcm_token) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'FCM token cannot be empty');
  END IF;

  INSERT INTO public.user_device_tokens (
    user_id,
    fcm_token,
    platform,
    device_id,
    is_active,
    last_seen_at,
    updated_at
  )
  VALUES (
    v_user_id,
    TRIM(p_fcm_token),
    COALESCE(p_platform, 'android'),
    p_device_id,
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id, fcm_token) DO UPDATE
  SET is_active = true,
      platform = EXCLUDED.platform,
      device_id = COALESCE(EXCLUDED.device_id, public.user_device_tokens.device_id),
      last_seen_at = NOW(),
      updated_at = NOW()
  RETURNING id INTO v_token_id;

  RETURN jsonb_build_object('success', true, 'id', v_token_id);
END;
$func$;

-- 4. Secure RPC: deactivate_device_token (e.g. on logout)
CREATE OR REPLACE FUNCTION public.deactivate_device_token(
  p_fcm_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  UPDATE public.user_device_tokens
  SET is_active = false,
      updated_at = NOW()
  WHERE user_id = v_user_id AND fcm_token = TRIM(p_fcm_token);

  RETURN jsonb_build_object('success', true);
END;
$func$;

-- 5. Secure RPC: mark_notification_read
CREATE OR REPLACE FUNCTION public.mark_notification_read(
  p_notification_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  UPDATE public.notifications
  SET read_at = NOW()
  WHERE id = p_notification_id AND recipient_user_id = v_user_id;

  RETURN jsonb_build_object('success', true);
END;
$func$;

-- 6. Row Level Security Policies
ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Device Tokens Policies
DROP POLICY IF EXISTS "Users can view own device tokens" ON public.user_device_tokens;
CREATE POLICY "Users can view own device tokens" ON public.user_device_tokens FOR SELECT
  USING (auth.uid() = user_id OR auth_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "Users can insert own device tokens" ON public.user_device_tokens;
CREATE POLICY "Users can insert own device tokens" ON public.user_device_tokens FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own device tokens" ON public.user_device_tokens;
CREATE POLICY "Users can update own device tokens" ON public.user_device_tokens FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own device tokens" ON public.user_device_tokens;
CREATE POLICY "Users can delete own device tokens" ON public.user_device_tokens FOR DELETE
  USING (auth.uid() = user_id);

-- Notifications Policies
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT
  USING (auth.uid() = recipient_user_id OR auth_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE
  USING (auth.uid() = recipient_user_id)
  WITH CHECK (auth.uid() = recipient_user_id);