-- ==============================================================================
-- Migration 007: User Sessions & Realtime Presence Tracking
-- ELITE College Event Management System
-- ==============================================================================

-- 1. Create public.user_sessions table
CREATE TABLE IF NOT EXISTS public.user_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  roll_number text,
  full_name text NOT NULL,
  role text NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'staff', 'admin')),
  department text DEFAULT 'Information Technology',
  year text,
  section text,
  platform text DEFAULT 'Android',
  device_info text,
  is_online boolean NOT NULL DEFAULT true,
  last_active_at timestamptz NOT NULL DEFAULT now(),
  login_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_sessions_user_platform_unique UNIQUE (user_id, platform)
);

-- 2. Indexes for high performance querying
CREATE INDEX IF NOT EXISTS idx_user_sessions_is_online ON public.user_sessions (is_online);
CREATE INDEX IF NOT EXISTS idx_user_sessions_last_active ON public.user_sessions (last_active_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_sessions_role ON public.user_sessions (role);
CREATE INDEX IF NOT EXISTS idx_user_sessions_roll ON public.user_sessions (roll_number);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
-- Allow all authenticated users to read sessions (e.g. for presence or admins)
DROP POLICY IF EXISTS "Anyone authenticated can view user sessions" ON public.user_sessions;
CREATE POLICY "Anyone authenticated can view user sessions"
  ON public.user_sessions FOR SELECT
  TO authenticated
  USING (true);

-- Allow public anon (used by admin portal if not using auth session or during direct sync) to read sessions
DROP POLICY IF EXISTS "Anon can view user sessions" ON public.user_sessions;
CREATE POLICY "Anon can view user sessions"
  ON public.user_sessions FOR SELECT
  TO anon
  USING (true);

-- Allow users to insert or update their own session
DROP POLICY IF EXISTS "Users can manage their own session" ON public.user_sessions;
CREATE POLICY "Users can manage their own session"
  ON public.user_sessions FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Allow anon service operations (for backend scripts or admin client)
DROP POLICY IF EXISTS "Anon can upsert sessions" ON public.user_sessions;
CREATE POLICY "Anon can upsert sessions"
  ON public.user_sessions FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- 5. Add to Supabase Realtime publication
ALTER TABLE public.user_sessions REPLICA IDENTITY FULL;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.user_sessions;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;
