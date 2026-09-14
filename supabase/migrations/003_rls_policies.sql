-- ==============================================================================
-- Migration 003: Row Level Security (RLS) Policies
-- ELITE College Event Management System
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Role Resolver Helper Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
  RETURN COALESCE(v_role, 'anon');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ------------------------------------------------------------------------------
-- Enable RLS On All Tables
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_coordinators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registration_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registration_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_option_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_attendance ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 1. Profiles Table Policies
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins have full access to profiles" ON public.profiles;
CREATE POLICY "Admins have full access to profiles"
  ON public.profiles FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Users can read profiles" ON public.profiles;
CREATE POLICY "Users can read profiles"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Public profile lookup" ON public.profiles;
CREATE POLICY "Public profile lookup"
  ON public.profiles FOR SELECT
  TO anon
  USING (true);

-- ------------------------------------------------------------------------------
-- 2. Events Table Policies
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins have full access to events" ON public.events;
CREATE POLICY "Admins have full access to events"
  ON public.events FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Staff can view all events" ON public.events;
CREATE POLICY "Staff can view all events"
  ON public.events FOR SELECT
  TO authenticated
  USING (public.get_current_user_role() = 'staff');

DROP POLICY IF EXISTS "Students and public can view published events" ON public.events;
CREATE POLICY "Students and public can view published events"
  ON public.events FOR SELECT
  TO public
  USING (status IN ('published', 'ongoing', 'completed'));

-- ------------------------------------------------------------------------------
-- 3. Event Coordinators Table Policies
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins have full access to coordinators" ON public.event_coordinators;
CREATE POLICY "Admins have full access to coordinators"
  ON public.event_coordinators FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Public can view event coordinators" ON public.event_coordinators;
CREATE POLICY "Public can view event coordinators"
  ON public.event_coordinators FOR SELECT
  TO public
  USING (true);

-- ------------------------------------------------------------------------------
-- 4. Teams & Team Members Policies
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins have full access to teams" ON public.teams;
CREATE POLICY "Admins have full access to teams"
  ON public.teams FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Authenticated users can view teams" ON public.teams;
CREATE POLICY "Authenticated users can view teams"
  ON public.teams FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Students can create team where they are leader" ON public.teams;
CREATE POLICY "Students can create team where they are leader"
  ON public.teams FOR INSERT
  TO authenticated
  WITH CHECK (leader_id = auth.uid());

DROP POLICY IF EXISTS "Team leader can update team" ON public.teams;
CREATE POLICY "Team leader can update team"
  ON public.teams FOR UPDATE
  TO authenticated
  USING (leader_id = auth.uid())
  WITH CHECK (leader_id = auth.uid());

-- Team Members
DROP POLICY IF EXISTS "Admins have full access to team members" ON public.team_members;
CREATE POLICY "Admins have full access to team members"
  ON public.team_members FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Authenticated users can view team members" ON public.team_members;
CREATE POLICY "Authenticated users can view team members"
  ON public.team_members FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Students can add members to team" ON public.team_members;
CREATE POLICY "Students can add members to team"
  ON public.team_members FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.teams t WHERE t.id = team_id AND t.leader_id = auth.uid())
    OR student_id = auth.uid()
  );

-- ------------------------------------------------------------------------------
-- 5. Event Registrations Policies
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins have full access to registrations" ON public.event_registrations;
CREATE POLICY "Admins have full access to registrations"
  ON public.event_registrations FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Staff can view event registrations" ON public.event_registrations;
CREATE POLICY "Staff can view event registrations"
  ON public.event_registrations FOR SELECT
  TO authenticated
  USING (public.get_current_user_role() = 'staff');

DROP POLICY IF EXISTS "Students can view own registration or team registrations" ON public.event_registrations;
CREATE POLICY "Students can view own registration or team registrations"
  ON public.event_registrations FOR SELECT
  TO authenticated
  USING (
    student_id = auth.uid()
    OR (
      team_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.team_members tm 
        WHERE tm.team_id = event_registrations.team_id AND tm.student_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "Students can register for events" ON public.event_registrations;
CREATE POLICY "Students can register for events"
  ON public.event_registrations FOR INSERT
  TO authenticated
  WITH CHECK (
    student_id = auth.uid()
    OR (
      team_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.teams t WHERE t.id = team_id AND t.leader_id = auth.uid()
      )
    )
  );

-- ------------------------------------------------------------------------------
-- 6. Dynamic Registration Form Fields & Answers
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins have full access to form fields" ON public.event_registration_fields;
CREATE POLICY "Admins have full access to form fields"
  ON public.event_registration_fields FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Users can view form fields for published events" ON public.event_registration_fields;
CREATE POLICY "Users can view form fields for published events"
  ON public.event_registration_fields FOR SELECT
  TO public
  USING (true);

DROP POLICY IF EXISTS "Admins have full access to form answers" ON public.event_registration_answers;
CREATE POLICY "Admins have full access to form answers"
  ON public.event_registration_answers FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Students can view own form answers" ON public.event_registration_answers;
CREATE POLICY "Students can view own form answers"
  ON public.event_registration_answers FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.event_registrations r
      WHERE r.id = registration_id AND r.student_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Students can submit form answers" ON public.event_registration_answers;
CREATE POLICY "Students can submit form answers"
  ON public.event_registration_answers FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.event_registrations r
      WHERE r.id = registration_id AND r.student_id = auth.uid()
    )
  );

-- ------------------------------------------------------------------------------
-- 7. Project Submissions & Images Policies
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins have full access to project submissions" ON public.project_submissions;
CREATE POLICY "Admins have full access to project submissions"
  ON public.project_submissions FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Public can view published project submissions" ON public.project_submissions;
CREATE POLICY "Public can view published project submissions"
  ON public.project_submissions FOR SELECT
  TO public
  USING (is_published IS TRUE);

DROP POLICY IF EXISTS "Students can view own project submission" ON public.project_submissions;
CREATE POLICY "Students can view own project submission"
  ON public.project_submissions FOR SELECT
  TO authenticated
  USING (
    submitted_by = auth.uid()
    OR (
      team_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.team_members tm 
        WHERE tm.team_id = project_submissions.team_id AND tm.student_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "Students can submit projects" ON public.project_submissions;
CREATE POLICY "Students can submit projects"
  ON public.project_submissions FOR INSERT
  TO authenticated
  WITH CHECK (
    submitted_by = auth.uid()
    OR (
      team_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.teams t WHERE t.id = team_id AND t.leader_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "Students can edit own project submission" ON public.project_submissions;
CREATE POLICY "Students can edit own project submission"
  ON public.project_submissions FOR UPDATE
  TO authenticated
  USING (
    submitted_by = auth.uid()
    OR (
      team_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.teams t WHERE t.id = team_id AND t.leader_id = auth.uid()
      )
    )
  );

-- Project Images
DROP POLICY IF EXISTS "Admins have full access to project images" ON public.project_images;
CREATE POLICY "Admins have full access to project images"
  ON public.project_images FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Public can view project images of published submissions" ON public.project_images;
CREATE POLICY "Public can view project images of published submissions"
  ON public.project_images FOR SELECT
  TO public
  USING (
    EXISTS (
      SELECT 1 FROM public.project_submissions ps 
      WHERE ps.id = project_submission_id AND (ps.is_published = true OR ps.submitted_by = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Submitters can add project images" ON public.project_images;
CREATE POLICY "Submitters can add project images"
  ON public.project_images FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.project_submissions ps 
      WHERE ps.id = project_submission_id AND (
        ps.submitted_by = auth.uid()
        OR (ps.team_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM public.team_members tm WHERE tm.team_id = ps.team_id AND tm.student_id = auth.uid()
        ))
      )
    )
  );

-- ------------------------------------------------------------------------------
-- 8. Polls, Poll Options & Poll Images Policies
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins have full access to polls" ON public.polls;
CREATE POLICY "Admins have full access to polls"
  ON public.polls FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Users can view active polls" ON public.polls;
CREATE POLICY "Users can view active polls"
  ON public.polls FOR SELECT
  TO public
  USING (is_active IS TRUE OR public.get_current_user_role() IN ('admin', 'staff'));

-- Poll Options
DROP POLICY IF EXISTS "Admins have full access to poll options" ON public.poll_options;
CREATE POLICY "Admins have full access to poll options"
  ON public.poll_options FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Public can view poll options" ON public.poll_options;
CREATE POLICY "Public can view poll options"
  ON public.poll_options FOR SELECT
  TO public
  USING (true);

-- Poll Option Images
DROP POLICY IF EXISTS "Admins have full access to poll option images" ON public.poll_option_images;
CREATE POLICY "Admins have full access to poll option images"
  ON public.poll_option_images FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Public can view poll option images" ON public.poll_option_images;
CREATE POLICY "Public can view poll option images"
  ON public.poll_option_images FOR SELECT
  TO public
  USING (true);

-- ------------------------------------------------------------------------------
-- 9. Poll Votes Policies (CRITICAL: STUDENTS CAN NEVER READ VOTE TOTALS)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins have full access to poll votes" ON public.poll_votes;
CREATE POLICY "Admins have full access to poll votes"
  ON public.poll_votes FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Staff can view poll votes for evaluation" ON public.poll_votes;
CREATE POLICY "Staff can view poll votes for evaluation"
  ON public.poll_votes FOR SELECT
  TO authenticated
  USING (public.get_current_user_role() = 'staff');

DROP POLICY IF EXISTS "Students can only see their own vote" ON public.poll_votes;
CREATE POLICY "Students can only see their own vote"
  ON public.poll_votes FOR SELECT
  TO authenticated
  USING (voter_id = auth.uid());

DROP POLICY IF EXISTS "Eligible users can cast vote" ON public.poll_votes;
CREATE POLICY "Eligible users can cast vote"
  ON public.poll_votes FOR INSERT
  TO authenticated
  WITH CHECK (voter_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 10. Event Attendance Policies
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins have full access to attendance" ON public.event_attendance;
CREATE POLICY "Admins have full access to attendance"
  ON public.event_attendance FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'admin')
  WITH CHECK (public.get_current_user_role() = 'admin');

DROP POLICY IF EXISTS "Staff can view and record attendance" ON public.event_attendance;
CREATE POLICY "Staff can view and record attendance"
  ON public.event_attendance FOR ALL
  TO authenticated
  USING (public.get_current_user_role() = 'staff')
  WITH CHECK (public.get_current_user_role() = 'staff');

DROP POLICY IF EXISTS "Students can view own attendance logs" ON public.event_attendance;
CREATE POLICY "Students can view own attendance logs"
  ON public.event_attendance FOR SELECT
  TO authenticated
  USING (student_id = auth.uid());
