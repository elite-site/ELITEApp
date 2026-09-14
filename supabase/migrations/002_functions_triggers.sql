-- ==============================================================================
-- Migration 002: Business Logic Functions & Server-Enforced Triggers
-- ELITE College Event Management System
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Automatic updated_at Timestamp Handler
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_events_updated_at ON public.events;
CREATE TRIGGER trg_events_updated_at
  BEFORE UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_teams_updated_at ON public.teams;
CREATE TRIGGER trg_teams_updated_at
  BEFORE UPDATE ON public.teams
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_event_registrations_updated_at ON public.event_registrations;
CREATE TRIGGER trg_event_registrations_updated_at
  BEFORE UPDATE ON public.event_registrations
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_project_submissions_updated_at ON public.project_submissions;
CREATE TRIGGER trg_project_submissions_updated_at
  BEFORE UPDATE ON public.project_submissions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_polls_updated_at ON public.polls;
CREATE TRIGGER trg_polls_updated_at
  BEFORE UPDATE ON public.polls
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ------------------------------------------------------------------------------
-- 2. Registration Rules & 10-Minute Deadline Enforcement
-- ------------------------------------------------------------------------------
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

  -- Calculate automatic deadline: 10 minutes prior to event start time
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

DROP TRIGGER IF EXISTS trg_check_registration_rules ON public.event_registrations;
CREATE TRIGGER trg_check_registration_rules
  BEFORE INSERT ON public.event_registrations
  FOR EACH ROW EXECUTE FUNCTION public.check_registration_rules();

-- ------------------------------------------------------------------------------
-- 3. Team Member Constraints (Fixed Size: 2 to 4 members, Single Team Per Event)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_team_member_rules()
RETURNS TRIGGER AS $$
DECLARE
  v_team RECORD;
  v_existing_count INTEGER;
  v_conflict_team_name TEXT;
  v_has_leader BOOLEAN;
BEGIN
  -- Fetch team and event
  SELECT * INTO v_team FROM public.teams WHERE id = NEW.team_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Team not found with ID %.', NEW.team_id;
  END IF;

  -- 1. Check max team size (Strict maximum = 4)
  SELECT COUNT(*) INTO v_existing_count 
  FROM public.team_members 
  WHERE team_id = NEW.team_id;

  IF v_existing_count >= 4 THEN
    RAISE EXCEPTION 'Team size limit exceeded: A team cannot have more than 4 members.';
  END IF;

  -- 2. Check if student already belongs to ANY team for this event
  SELECT t.team_name INTO v_conflict_team_name
  FROM public.team_members tm
  JOIN public.teams t ON tm.team_id = t.id
  WHERE t.event_id = v_team.event_id
    AND tm.student_id = NEW.student_id
    AND tm.team_id <> NEW.team_id
  LIMIT 1;

  IF v_conflict_team_name IS NOT NULL THEN
    RAISE EXCEPTION 'Duplicate team participation: Student already belongs to team "%" for this event.', v_conflict_team_name;
  END IF;

  -- 3. Ensure only one team leader per team
  IF NEW.is_leader IS TRUE THEN
    SELECT EXISTS (
      SELECT 1 FROM public.team_members 
      WHERE team_id = NEW.team_id AND is_leader = true
    ) INTO v_has_leader;

    IF v_has_leader THEN
      RAISE EXCEPTION 'Single leader rule: Team "%" already has a designated leader.', v_team.team_name;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_check_team_member_rules ON public.team_members;
CREATE TRIGGER trg_check_team_member_rules
  BEFORE INSERT ON public.team_members
  FOR EACH ROW EXECUTE FUNCTION public.check_team_member_rules();

-- ------------------------------------------------------------------------------
-- 4. Project Submission Deadline Lockdown
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_project_submission_deadline()
RETURNS TRIGGER AS $$
DECLARE
  v_event RECORD;
BEGIN
  SELECT * INTO v_event FROM public.events WHERE id = NEW.event_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event not found with ID %.', NEW.event_id;
  END IF;

  IF v_event.submission_enabled IS NOT TRUE THEN
    RAISE EXCEPTION 'Project submissions are not enabled for this event.';
  END IF;

  IF v_event.submission_deadline IS NOT NULL AND NOW() > v_event.submission_deadline THEN
    RAISE EXCEPTION 'Submission Locked: The deadline has passed (%). Changes cannot be saved.', v_event.submission_deadline;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_check_project_submission_deadline ON public.project_submissions;
CREATE TRIGGER trg_check_project_submission_deadline
  BEFORE INSERT OR UPDATE ON public.project_submissions
  FOR EACH ROW EXECUTE FUNCTION public.check_project_submission_deadline();

-- ------------------------------------------------------------------------------
-- 5. Poll Voting Eligibility & Immutability Rules
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_poll_voting_rules()
RETURNS TRIGGER AS $$
DECLARE
  v_poll RECORD;
  v_voter_role TEXT;
BEGIN
  SELECT * INTO v_poll FROM public.polls WHERE id = NEW.poll_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Poll not found with ID %.', NEW.poll_id;
  END IF;

  -- 1. Check poll status
  IF v_poll.is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'Voting is closed: This poll is not active.';
  END IF;

  -- 2. Check timing
  IF v_poll.starts_at > NOW() THEN
    RAISE EXCEPTION 'Voting has not started yet (Starts at: %).', v_poll.starts_at;
  END IF;

  IF v_poll.ends_at IS NOT NULL AND v_poll.ends_at < NOW() THEN
    RAISE EXCEPTION 'Voting has ended (Ended at: %).', v_poll.ends_at;
  END IF;

  -- 3. Check voter role eligibility
  SELECT role INTO v_voter_role FROM public.profiles WHERE id = NEW.voter_id;
  IF NOT (v_voter_role = ANY(v_poll.voting_eligible_roles)) THEN
    RAISE EXCEPTION 'Role not eligible: Your role (%) is not permitted to vote in this poll.', v_voter_role;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_check_poll_voting_rules ON public.poll_votes;
CREATE TRIGGER trg_check_poll_voting_rules
  BEFORE INSERT ON public.poll_votes
  FOR EACH ROW EXECUTE FUNCTION public.check_poll_voting_rules();

-- Immutability: Block update or deletion of cast votes
CREATE OR REPLACE FUNCTION public.prevent_vote_mutation()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Vote locked: Once cast, a vote cannot be modified or deleted.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_vote_update ON public.poll_votes;
CREATE TRIGGER trg_prevent_vote_update
  BEFORE UPDATE OR DELETE ON public.poll_votes
  FOR EACH ROW EXECUTE FUNCTION public.prevent_vote_mutation();

-- ------------------------------------------------------------------------------
-- 6. Confidential Poll Results Accessor (Admin & Staff Only)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_poll_results(p_poll_id UUID)
RETURNS TABLE (
  option_id UUID,
  title TEXT,
  description TEXT,
  vote_count BIGINT
) AS $$
DECLARE
  v_caller_role TEXT;
BEGIN
  SELECT role INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'staff') THEN
    RAISE EXCEPTION 'Permission denied: Vote totals are confidential and accessible only to administrators.';
  END IF;

  RETURN QUERY
  SELECT 
    po.id AS option_id,
    po.title,
    po.description,
    COUNT(pv.id) AS vote_count
  FROM public.poll_options po
  LEFT JOIN public.poll_votes pv ON po.id = pv.poll_option_id
  WHERE po.poll_id = p_poll_id
  GROUP BY po.id, po.title, po.description, po.display_order
  ORDER BY po.display_order ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------------------------
-- 7. Direct SQL Execution Helper for Admin Console
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.execute_sql_query(query_text text)
RETURNS jsonb AS $$
DECLARE
  result jsonb;
BEGIN
  EXECUTE 'SELECT jsonb_agg(t) FROM (' || query_text || ') t' INTO result;
  RETURN COALESCE(result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.execute_sql_query(text) TO public;

