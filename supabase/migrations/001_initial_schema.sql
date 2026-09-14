-- ==============================================================================
-- Migration 001: Initial Relational Schema
-- ELITE College Event Management System
-- Database: PostgreSQL (Supabase)
-- ==============================================================================

-- Enable UUID extension if not present
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 1. Profiles Table (Linked to auth.users)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  roll_number TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  department TEXT NOT NULL DEFAULT 'Information Technology',
  year TEXT,
  section TEXT,
  role TEXT NOT NULL CHECK (role IN ('student', 'staff', 'admin')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 2. Events Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('individual', 'team')),
  image_url TEXT,
  rules_pdf_url TEXT,
  instructions TEXT,
  prize_details TEXT,
  contact_information TEXT,
  venue TEXT NOT NULL,
  event_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME,
  registration_enabled BOOLEAN NOT NULL DEFAULT true,
  registration_closed_manually BOOLEAN NOT NULL DEFAULT false,
  submission_enabled BOOLEAN NOT NULL DEFAULT false,
  submission_deadline TIMESTAMPTZ,
  voting_enabled BOOLEAN NOT NULL DEFAULT false,
  voting_start TIMESTAMPTZ,
  voting_end TIMESTAMPTZ,
  voting_eligible_roles TEXT[] NOT NULL DEFAULT ARRAY['student', 'staff'],
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'ongoing', 'completed', 'cancelled')),
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 3. Event Coordinators Table (Supports single now, multiple coordinators later)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.event_coordinators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  staff_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_event_coordinator UNIQUE (event_id, staff_id)
);

-- ------------------------------------------------------------------------------
-- 4. Teams Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  team_name TEXT NOT NULL,
  leader_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_event_team_name UNIQUE (event_id, team_name)
);

-- ------------------------------------------------------------------------------
-- 5. Team Members Table (Fixed team size: 2 to 4 members)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_leader BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT uq_team_student UNIQUE (team_id, student_id)
);

-- ------------------------------------------------------------------------------
-- 6. Event Registrations Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.event_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE,
  registration_status TEXT NOT NULL DEFAULT 'confirmed' CHECK (registration_status IN ('confirmed', 'cancelled', 'waitlisted')),
  registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_event_student_registration UNIQUE (event_id, student_id)
);

-- ------------------------------------------------------------------------------
-- 7. Dynamic Registration Form Fields
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.event_registration_fields (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  field_name TEXT NOT NULL,
  field_label TEXT NOT NULL,
  field_type TEXT NOT NULL CHECK (field_type IN ('text', 'textarea', 'number', 'email', 'phone', 'dropdown', 'checkbox', 'file', 'URL')),
  is_required BOOLEAN NOT NULL DEFAULT false,
  display_order INTEGER NOT NULL DEFAULT 0,
  options JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 8. Dynamic Registration Answers
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.event_registration_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id UUID NOT NULL REFERENCES public.event_registrations(id) ON DELETE CASCADE,
  field_id UUID NOT NULL REFERENCES public.event_registration_fields(id) ON DELETE CASCADE,
  answer_text TEXT,
  answer_json JSONB,
  file_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_registration_field_answer UNIQUE (registration_id, field_id)
);

-- ------------------------------------------------------------------------------
-- 9. Project Submissions Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.project_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE,
  submitted_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  project_title TEXT NOT NULL,
  description TEXT NOT NULL,
  problem_statement TEXT,
  solution TEXT,
  technologies TEXT[],
  github_url TEXT,
  live_demo_url TEXT,
  documentation_url TEXT,
  ppt_url TEXT,
  status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'under_review', 'approved', 'rejected')),
  is_published BOOLEAN NOT NULL DEFAULT false,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 10. Project Images Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.project_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_submission_id UUID NOT NULL REFERENCES public.project_submissions(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  public_url TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 11. Polls Table (Campus Opinion Polls & Showcase Voting)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.polls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ends_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT true,
  voting_eligible_roles TEXT[] NOT NULL DEFAULT ARRAY['student', 'staff'],
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 12. Poll Options Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.poll_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  project_submission_id UUID REFERENCES public.project_submissions(id) ON DELETE SET NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 13. Poll Option Images Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.poll_option_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_option_id UUID NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  public_url TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 14. Poll Votes Table (One vote per user per poll enforced at database level)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.poll_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  poll_option_id UUID NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
  voter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  voted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_poll_single_voter UNIQUE (poll_id, voter_id)
);

-- ------------------------------------------------------------------------------
-- 15. Event Attendance Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.event_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  scanned_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'present' CHECK (status IN ('present', 'late', 'absent')),
  session TEXT NOT NULL DEFAULT 'Main',
  scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- INDEXES FOR HIGH-PERFORMANCE QUERIES
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_profiles_roll_number ON public.profiles(roll_number);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_events_event_date ON public.events(event_date);
CREATE INDEX IF NOT EXISTS idx_events_status ON public.events(status);
CREATE INDEX IF NOT EXISTS idx_events_event_type ON public.events(event_type);
CREATE INDEX IF NOT EXISTS idx_registrations_event ON public.event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_registrations_student ON public.event_registrations(student_id);
CREATE INDEX IF NOT EXISTS idx_registrations_team ON public.event_registrations(team_id);
CREATE INDEX IF NOT EXISTS idx_teams_event ON public.teams(event_id);
CREATE INDEX IF NOT EXISTS idx_teams_leader ON public.teams(leader_id);
CREATE INDEX IF NOT EXISTS idx_team_members_team ON public.team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_student ON public.team_members(student_id);
CREATE INDEX IF NOT EXISTS idx_project_submissions_event ON public.project_submissions(event_id);
CREATE INDEX IF NOT EXISTS idx_project_submissions_team ON public.project_submissions(team_id);
CREATE INDEX IF NOT EXISTS idx_project_submissions_published ON public.project_submissions(is_published);
CREATE INDEX IF NOT EXISTS idx_polls_event ON public.polls(event_id);
CREATE INDEX IF NOT EXISTS idx_polls_is_active ON public.polls(is_active);
CREATE INDEX IF NOT EXISTS idx_poll_options_poll ON public.poll_options(poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_votes_poll ON public.poll_votes(poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_votes_voter ON public.poll_votes(voter_id);
CREATE INDEX IF NOT EXISTS idx_attendance_event ON public.event_attendance(event_id);
CREATE INDEX IF NOT EXISTS idx_attendance_student ON public.event_attendance(student_id);
