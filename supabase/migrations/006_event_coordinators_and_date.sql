-- ==============================================================================
-- Migration 006: Event Coordinators & Nullable Event Date
-- ELITE College Event Management System
-- ==============================================================================

-- 1. Allow event_date to be nullable in public.events (for events with TBD/undated schedules like Meme Mania)
ALTER TABLE public.events ALTER COLUMN event_date DROP NOT NULL;

-- 2. Enhance event_coordinators to support both faculty and student coordinators relationally,
-- with coordinator_name and coordinator_type, while staff_id is nullable (to avoid fake profile creation).
ALTER TABLE public.event_coordinators ALTER COLUMN staff_id DROP NOT NULL;
ALTER TABLE public.event_coordinators ADD COLUMN IF NOT EXISTS coordinator_name TEXT;
ALTER TABLE public.event_coordinators ADD COLUMN IF NOT EXISTS coordinator_type TEXT DEFAULT 'faculty' CHECK (coordinator_type IN ('faculty', 'student'));

-- Drop old constraint that required (event_id, staff_id)
ALTER TABLE public.event_coordinators DROP CONSTRAINT IF EXISTS uq_event_coordinator;

-- Ensure unique coordinator per event by name and type
ALTER TABLE public.event_coordinators DROP CONSTRAINT IF EXISTS uq_event_coordinator_unique;
ALTER TABLE public.event_coordinators ADD CONSTRAINT uq_event_coordinator_unique UNIQUE (event_id, coordinator_name, coordinator_type);

-- 3. Update check_registration_rules trigger function to safely handle NULL event_date
CREATE OR REPLACE FUNCTION public.check_registration_rules()
RETURNS TRIGGER AS $$
DECLARE
  v_event RECORD;
  v_event_start TIMESTAMPTZ;
  v_cutoff TIMESTAMPTZ;
  v_caller_role TEXT;
BEGIN
  -- Fetch event details
  SELECT * INTO v_event FROM public.events WHERE id = NEW.event_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event with ID % not found.', NEW.event_id;
  END IF;

  -- Check if event is published
  IF v_event.status <> 'published' AND v_event.status <> 'ongoing' THEN
    RAISE EXCEPTION 'Registration is not available for unpublished or closed events (Status: %).', v_event.status;
  END IF;

  -- Check manual close toggle
  IF v_event.registration_closed_manually IS TRUE OR v_event.registration_enabled IS NOT TRUE THEN
    RAISE EXCEPTION 'Registration is currently closed by the event administrator.';
  END IF;

  -- Calculate automatic deadline: 10 minutes prior to event start time (if date and time are set)
  IF v_event.event_date IS NOT NULL AND v_event.start_time IS NOT NULL THEN
    v_event_start := (v_event.event_date + v_event.start_time)::TIMESTAMPTZ;
    v_cutoff := v_event_start - INTERVAL '10 minutes';

    -- Get current user role (from JWT or profiles)
    SELECT role INTO v_caller_role FROM public.profiles WHERE id = auth.uid();

    -- Admin manual bypass allows adding students after normal deadline
    IF COALESCE(v_caller_role, 'student') <> 'admin' THEN
      IF NOW() > v_cutoff THEN
        RAISE EXCEPTION 'Registration closed: Registration closes automatically 10 minutes before event start (% cutoff: %).', v_event_start, v_cutoff;
      END IF;
    END IF;
  END IF;

  -- Validate participation type matching
  IF v_event.event_type = 'team' AND NEW.team_id IS NULL THEN
    RAISE EXCEPTION 'Invalid registration: This is a team event. A team_id must be specified.';
  END IF;

  IF v_event.event_type = 'individual' AND NEW.team_id IS NOT NULL THEN
    RAISE EXCEPTION 'Invalid registration: This is an individual event. team_id must be NULL.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
