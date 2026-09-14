-- ====================================================
-- BACKUP OF ALL PUBLIC TABLES BEFORE DROP
-- Exported at: 2026-09-14T09:21:02.455Z
-- ====================================================

CREATE TABLE IF NOT EXISTS public."academic_years" (
  "id" text NOT NULL,
  "year_name" text NOT NULL,
  "is_current" boolean DEFAULT false,
  "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."alerts" (
  "id" text NOT NULL,
  "title" text NOT NULL,
  "content" text NOT NULL,
  "alert_type" text NOT NULL DEFAULT 'INFO'::text,
  "target_audience" text NOT NULL DEFAULT 'ALL'::text,
  "is_published" boolean DEFAULT true,
  "expires_at" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."announcements" (
  "id" text NOT NULL,
  "title" text NOT NULL,
  "content" text NOT NULL,
  "image_url" text,
  "is_published" boolean DEFAULT true,
  "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."audit_logs" (
  "id" text NOT NULL,
  "user_id" text,
  "user_name" text,
  "user_role" text,
  "action" text NOT NULL,
  "target_entity" text NOT NULL,
  "details" text,
  "timestamp" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."event_attendance" (
  "id" text NOT NULL,
  "event_id" text NOT NULL,
  "student_id" text NOT NULL,
  "student_roll" text,
  "student_name" text,
  "student_email" text,
  "scanned_by" text NOT NULL DEFAULT 'Turnstile Gate #2'::text,
  "scanned_by_name" text DEFAULT 'Turnstile Scanner'::text,
  "status" text NOT NULL DEFAULT 'PRESENT'::text,
  "session" text NOT NULL DEFAULT 'DEFAULT'::text,
  "scanned_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."event_registrations" (
  "id" text NOT NULL,
  "event_id" text NOT NULL,
  "student_id" text NOT NULL,
  "student_roll" text,
  "student_name" text,
  "student_email" text,
  "student_year" text,
  "team_name" text,
  "status" text NOT NULL DEFAULT 'CONFIRMED'::text,
  "registered_at" timestamp with time zone DEFAULT now(),
  "is_team" boolean DEFAULT false,
  "members" jsonb DEFAULT '[]'::jsonb
);

CREATE TABLE IF NOT EXISTS public."event_staff" (
  "id" text NOT NULL,
  "event_id" text NOT NULL,
  "staff_id" text NOT NULL,
  "assigned_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."events" (
  "id" text NOT NULL,
  "title" text NOT NULL,
  "description" text NOT NULL,
  "banner_url" text,
  "event_date" date NOT NULL DEFAULT CURRENT_DATE,
  "start_time" text NOT NULL DEFAULT '10:00 AM'::text,
  "end_time" text DEFAULT '04:00 PM'::text,
  "reg_start" timestamp with time zone,
  "reg_end" timestamp with time zone,
  "max_capacity" integer NOT NULL DEFAULT 100,
  "registered_count" integer NOT NULL DEFAULT 0,
  "venue" text NOT NULL DEFAULT 'Campus Auditorium'::text,
  "event_type" text NOT NULL DEFAULT 'Technical'::text,
  "eligible_years" text NOT NULL DEFAULT 'All'::text,
  "visibility" text NOT NULL DEFAULT 'PUBLIC'::text,
  "status" text NOT NULL DEFAULT 'OPEN'::text,
  "platform_url" text,
  "platform_config" text,
  "faculty_coordinators" text DEFAULT 'IT Department Faculty'::text,
  "student_coordinators" text,
  "rules" text,
  "prerequisites" text,
  "participation_type" text DEFAULT 'Individual'::text,
  "created_by" text,
  "created_at" timestamp with time zone DEFAULT now(),
  "is_project_submission_enabled" boolean DEFAULT false,
  "project_submission_deadline" timestamp with time zone,
  "is_voting_enabled" boolean DEFAULT false,
  "voting_start" timestamp with time zone,
  "voting_end" timestamp with time zone,
  "voting_eligible_roles" ARRAY DEFAULT ARRAY['STUDENT'::text, 'STAFF'::text]
);

CREATE TABLE IF NOT EXISTS public."fcm_tokens" (
  "token" text NOT NULL,
  "user_id" text NOT NULL,
  "year_level" text,
  "role" text DEFAULT 'STUDENT'::text,
  "active" boolean DEFAULT true,
  "platform" text DEFAULT 'android'::text,
  "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."notification_reads" (
  "id" text NOT NULL,
  "notification_id" text NOT NULL,
  "user_id" text NOT NULL,
  "read_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."notifications" (
  "id" text NOT NULL,
  "title" text NOT NULL,
  "message" text NOT NULL,
  "category" text DEFAULT 'Urgent'::text,
  "target_audience" text DEFAULT 'ALL'::text,
  "target_event_id" text,
  "sent_by" text,
  "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."poll_options" (
  "id" text NOT NULL,
  "poll_id" text NOT NULL,
  "text" text NOT NULL,
  "vote_count" integer NOT NULL DEFAULT 0,
  "image_url" text,
  "description" text
);

CREATE TABLE IF NOT EXISTS public."poll_votes" (
  "id" text NOT NULL,
  "poll_id" text NOT NULL,
  "option_id" text NOT NULL,
  "student_id" text NOT NULL,
  "voted_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."polls" (
  "id" text NOT NULL,
  "question" text NOT NULL,
  "description" text,
  "category" text DEFAULT 'Department'::text,
  "target_years" text DEFAULT 'All'::text,
  "status" text NOT NULL DEFAULT 'OPEN'::text,
  "winner_option_id" text,
  "created_by" text,
  "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."profiles" (
  "id" text NOT NULL,
  "name" text NOT NULL,
  "email" text NOT NULL,
  "student_id" text,
  "department" text NOT NULL DEFAULT 'Information Technology'::text,
  "year" text,
  "section" text,
  "role" text NOT NULL,
  "status" text NOT NULL DEFAULT 'ACTIVE'::text,
  "academic_details" text,
  "phone_number" text,
  "lab_pass_id" text,
  "lab_pass_room" text DEFAULT 'IT Lab & Turnstile Gate #2'::text,
  "lab_pass_expiry" text DEFAULT 'AY 2026-2027'::text,
  "cgpa" numeric DEFAULT 8.94,
  "attendance_percent" integer DEFAULT 90,
  "created_at" timestamp with time zone DEFAULT now(),
  "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."project_submissions" (
  "id" text NOT NULL,
  "event_id" text NOT NULL,
  "registration_id" text NOT NULL,
  "team_name" text NOT NULL,
  "leader_id" text NOT NULL,
  "leader_name" text NOT NULL,
  "project_name" text NOT NULL,
  "short_description" text,
  "detailed_description" text,
  "technologies" ARRAY DEFAULT '{}'::text[],
  "repo_url" text,
  "demo_url" text,
  "documentation_url" text,
  "presentation_url" text,
  "image_url" text,
  "status" text NOT NULL DEFAULT 'PENDING'::text,
  "vote_count" integer NOT NULL DEFAULT 0,
  "created_at" timestamp with time zone DEFAULT now(),
  "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."project_votes" (
  "id" text NOT NULL,
  "event_id" text NOT NULL,
  "project_id" text NOT NULL,
  "voter_id" text NOT NULL,
  "voter_role" text NOT NULL,
  "voted_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."staff" (
  "user_id" text NOT NULL,
  "employee_id" text NOT NULL,
  "name" text NOT NULL,
  "designation" text DEFAULT 'Assistant Professor'::text,
  "department" text NOT NULL DEFAULT 'Information Technology'::text,
  "phone" text,
  "cabin" text DEFAULT 'IT Staff Room A'::text,
  "created_at" timestamp with time zone DEFAULT now(),
  "password_hash" text,
  "username" text
);

CREATE TABLE IF NOT EXISTS public."student_queries" (
  "id" text NOT NULL,
  "student_name" text NOT NULL,
  "roll_no" text NOT NULL,
  "email" text,
  "year_level" text,
  "category" text DEFAULT 'Lab Support'::text,
  "mentor" text DEFAULT 'IT Helpdesk'::text,
  "title" text NOT NULL,
  "description" text,
  "urgency" text DEFAULT 'Normal'::text,
  "status" text DEFAULT 'QUEUED'::text,
  "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public."students" (
  "user_id" text NOT NULL,
  "roll_no" text NOT NULL,
  "name" text NOT NULL,
  "department" text NOT NULL DEFAULT 'Information Technology'::text,
  "year_level" text NOT NULL,
  "section" text DEFAULT 'B'::text,
  "academic_year_id" text,
  "qr_token" text NOT NULL,
  "status" text NOT NULL DEFAULT 'ACTIVE'::text,
  "created_at" timestamp with time zone DEFAULT now(),
  "updated_at" timestamp with time zone DEFAULT now(),
  "password_hash" text
);

CREATE TABLE IF NOT EXISTS public."users" (
  "id" text NOT NULL,
  "username" text NOT NULL,
  "email" text,
  "password_hash" text DEFAULT 'MANAGED_AUTH'::text,
  "role" text NOT NULL,
  "department" text NOT NULL DEFAULT 'Information Technology'::text,
  "status" text NOT NULL DEFAULT 'ACTIVE'::text,
  "must_change_password" boolean DEFAULT false,
  "created_at" timestamp with time zone DEFAULT now(),
  "updated_at" timestamp with time zone DEFAULT now()
);

