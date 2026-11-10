-- Run in the TravelAgency project's SQL Editor. Safe to run again.
-- Notification producers use a trusted backend/service role. Flutter may only
-- read its own inbox and update is_read. Ownership is the Supabase Auth UID.
BEGIN;

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  type varchar NOT NULL CHECK (type IN ('reward', 'booking', 'system')),
  title text NOT NULL,
  message text NOT NULL,
  is_read boolean DEFAULT false,
  deep_link text,
  created_at timestamptz DEFAULT now()
);

-- Fail rather than silently adopt the incompatible shop design (body/action_url).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM unnest(ARRAY['id','user_id','type','title','message',
      'is_read','deep_link','created_at']) AS required(column_name)
    WHERE NOT EXISTS (
      SELECT 1 FROM information_schema.columns c
      WHERE c.table_schema = 'public' AND c.table_name = 'notifications'
        AND c.column_name = required.column_name
    )
  ) THEN
    RAISE EXCEPTION 'Existing notifications schema differs from the mobile contract; reconcile it before enabling realtime.';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS notifications_user_created_idx
  ON public.notifications (user_id, created_at DESC);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- A restrictive policy also bounds any older permissive policy on this table.
DROP POLICY IF EXISTS notifications_mobile_owner ON public.notifications;
CREATE POLICY notifications_mobile_owner ON public.notifications AS RESTRICTIVE
  FOR ALL TO authenticated
  USING (user_id::text = (SELECT auth.uid())::text)
  WITH CHECK (user_id::text = (SELECT auth.uid())::text);

DROP POLICY IF EXISTS notifications_mobile_select ON public.notifications;
CREATE POLICY notifications_mobile_select ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id::text = (SELECT auth.uid())::text);

DROP POLICY IF EXISTS notifications_mobile_read ON public.notifications;
CREATE POLICY notifications_mobile_read ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id::text = (SELECT auth.uid())::text)
  WITH CHECK (user_id::text = (SELECT auth.uid())::text);

REVOKE ALL ON public.notifications FROM PUBLIC, anon, authenticated;
-- Clear any historical column-level write privileges as well.
DO $$
DECLARE columns_sql text;
BEGIN
  SELECT string_agg(quote_ident(attname), ', ') INTO columns_sql
  FROM pg_attribute WHERE attrelid = 'public.notifications'::regclass
    AND attnum > 0 AND NOT attisdropped;
  EXECUTE format('REVOKE INSERT (%s), UPDATE (%s), REFERENCES (%s) ON public.notifications FROM PUBLIC, anon, authenticated',
    columns_sql, columns_sql, columns_sql);
END $$;
GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (is_read) ON public.notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO service_role;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    RAISE EXCEPTION 'supabase_realtime publication is missing; check the project Realtime setup.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

COMMIT;
