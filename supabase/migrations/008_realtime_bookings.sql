-- Migration 008: Enable Supabase Realtime for Bookings
-- Enables postgres_changes broadcasts for public.bookings and ensures full row payloads on UPDATE/DELETE

-- 1. Set replica identity to FULL so UPDATE and DELETE events include all column values
ALTER TABLE public.bookings REPLICA IDENTITY FULL;

-- 2. Add public.bookings to the supabase_realtime publication if not already present
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
