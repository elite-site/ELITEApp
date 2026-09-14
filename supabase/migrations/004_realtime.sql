-- ==============================================================================
-- Migration 004: Supabase Realtime Publications
-- ELITE College Event Management System
-- ==============================================================================

-- Set replica identity to FULL for tables requiring detailed realtime deltas
ALTER TABLE public.event_registrations REPLICA IDENTITY FULL;
ALTER TABLE public.teams REPLICA IDENTITY FULL;
ALTER TABLE public.team_members REPLICA IDENTITY FULL;
ALTER TABLE public.project_submissions REPLICA IDENTITY FULL;
ALTER TABLE public.polls REPLICA IDENTITY FULL;
ALTER TABLE public.poll_votes REPLICA IDENTITY FULL;
ALTER TABLE public.events REPLICA IDENTITY FULL;
ALTER TABLE public.event_attendance REPLICA IDENTITY FULL;

-- Ensure supabase_realtime publication exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

-- Add required tables to supabase_realtime publication
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE 
    public.event_registrations,
    public.teams,
    public.team_members,
    public.project_submissions,
    public.polls,
    public.poll_votes,
    public.events,
    public.event_attendance;
EXCEPTION
  WHEN duplicate_object THEN
    NULL; -- table already in publication
END $$;
