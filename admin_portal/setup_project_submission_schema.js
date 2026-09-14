import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function migrate() {
  const client = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false }
  });

  await client.connect();
  console.log("Connected to Supabase PostgreSQL.");

  // 1. Add columns to events table if not existing
  console.log("Adding configurable project & voting columns to events table...");
  await client.query(`
    ALTER TABLE public.events 
    ADD COLUMN IF NOT EXISTS is_project_submission_enabled BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS project_submission_deadline TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS is_voting_enabled BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS voting_start TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS voting_end TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS voting_eligible_roles TEXT[] DEFAULT ARRAY['STUDENT', 'STAFF'];
  `);

  // Update existing technical / project events to have project submission enabled
  await client.query(`
    UPDATE public.events 
    SET 
      is_project_submission_enabled = TRUE,
      project_submission_deadline = '2026-09-15 18:00:00+05:30',
      is_voting_enabled = TRUE,
      voting_start = '2026-09-15 09:00:00+05:30',
      voting_end = '2026-09-15 20:00:00+05:30',
      voting_eligible_roles = ARRAY['STUDENT', 'STAFF']
    WHERE id IN ('ev_vibe_coding', 'ev_idea_pitch') OR participation_type ILIKE '%team%';
  `);

  // 2. Add columns to poll_options
  console.log("Adding image_url and description to poll_options table...");
  await client.query(`
    ALTER TABLE public.poll_options
    ADD COLUMN IF NOT EXISTS image_url TEXT,
    ADD COLUMN IF NOT EXISTS description TEXT;
  `);

  // 3. Create project_submissions table
  console.log("Creating project_submissions table...");
  await client.query(`
    CREATE TABLE IF NOT EXISTS public.project_submissions (
      id TEXT PRIMARY KEY,
      event_id TEXT NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
      registration_id TEXT NOT NULL REFERENCES public.event_registrations(id) ON DELETE CASCADE,
      team_name TEXT NOT NULL,
      leader_id TEXT NOT NULL REFERENCES public.users(id),
      leader_name TEXT NOT NULL,
      project_name TEXT NOT NULL,
      short_description TEXT,
      detailed_description TEXT,
      technologies TEXT[] DEFAULT '{}',
      repo_url TEXT,
      demo_url TEXT,
      documentation_url TEXT,
      presentation_url TEXT,
      image_url TEXT,
      status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PUBLISHED', 'REJECTED')),
      vote_count INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(event_id, registration_id)
    );

    CREATE INDEX IF NOT EXISTS idx_proj_event_status ON public.project_submissions(event_id, status);
    CREATE INDEX IF NOT EXISTS idx_proj_leader ON public.project_submissions(leader_id);
  `);

  // 4. Create project_votes table with STRICT ONE USER = ONE VOTE per event
  console.log("Creating project_votes table...");
  await client.query(`
    CREATE TABLE IF NOT EXISTS public.project_votes (
      id TEXT PRIMARY KEY,
      event_id TEXT NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
      project_id TEXT NOT NULL REFERENCES public.project_submissions(id) ON DELETE CASCADE,
      voter_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
      voter_role TEXT NOT NULL CHECK (voter_role IN ('STUDENT', 'STAFF', 'SUPER_ADMIN')),
      voted_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(event_id, voter_id)
    );

    CREATE INDEX IF NOT EXISTS idx_proj_votes_proj ON public.project_votes(project_id);
    CREATE INDEX IF NOT EXISTS idx_proj_votes_voter ON public.project_votes(event_id, voter_id);
  `);

  // 5. Database function & trigger for authoritative server-side deadline enforcement
  console.log("Setting up authoritative deadline enforcement trigger...");
  await client.query(`
    CREATE OR REPLACE FUNCTION check_project_submission_deadline()
    RETURNS TRIGGER AS $$
    DECLARE
      v_deadline TIMESTAMPTZ;
      v_enabled BOOLEAN;
    BEGIN
      SELECT project_submission_deadline, is_project_submission_enabled
      INTO v_deadline, v_enabled
      FROM public.events
      WHERE id = NEW.event_id;

      -- If project submission is not enabled for this event
      IF v_enabled IS NOT TRUE THEN
        RAISE EXCEPTION 'Project submissions are not enabled for this event.';
      END IF;

      -- If deadline has passed, block insert and update
      IF v_deadline IS NOT NULL AND NOW() > v_deadline THEN
        RAISE EXCEPTION 'Submission Locked: The submission deadline has passed (%). Changes cannot be saved.', v_deadline;
      END IF;

      NEW.updated_at = NOW();
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    DROP TRIGGER IF EXISTS trg_check_project_submission_deadline ON public.project_submissions;
    CREATE TRIGGER trg_check_project_submission_deadline
    BEFORE INSERT OR UPDATE ON public.project_submissions
    FOR EACH ROW
    EXECUTE FUNCTION check_project_submission_deadline();
  `);

  // 6. Database function & trigger for authoritative voting eligibility & deadline enforcement
  console.log("Setting up authoritative voting rules enforcement trigger...");
  await client.query(`
    CREATE OR REPLACE FUNCTION check_project_voting_eligibility()
    RETURNS TRIGGER AS $$
    DECLARE
      v_voting_enabled BOOLEAN;
      v_start TIMESTAMPTZ;
      v_end TIMESTAMPTZ;
      v_eligible_roles TEXT[];
      v_proj_status TEXT;
    BEGIN
      -- Check event voting config
      SELECT is_voting_enabled, voting_start, voting_end, voting_eligible_roles
      INTO v_voting_enabled, v_start, v_end, v_eligible_roles
      FROM public.events
      WHERE id = NEW.event_id;

      IF v_voting_enabled IS NOT TRUE THEN
        RAISE EXCEPTION 'Voting is not enabled for this event.';
      END IF;

      IF v_start IS NOT NULL AND NOW() < v_start THEN
        RAISE EXCEPTION 'Voting has not started yet.';
      END IF;

      IF v_end IS NOT NULL AND NOW() > v_end THEN
        RAISE EXCEPTION 'Voting has ended.';
      END IF;

      -- Check voter role
      IF v_eligible_roles IS NOT NULL AND NOT (NEW.voter_role = ANY(v_eligible_roles)) THEN
        RAISE EXCEPTION 'Your role (%) is not eligible to vote in this event.', NEW.voter_role;
      END IF;

      -- Check project is published
      SELECT status INTO v_proj_status
      FROM public.project_submissions
      WHERE id = NEW.project_id;

      IF v_proj_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'Cannot vote on an unpublished project.';
      END IF;

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    DROP TRIGGER IF EXISTS trg_check_project_voting_eligibility ON public.project_votes;
    CREATE TRIGGER trg_check_project_voting_eligibility
    BEFORE INSERT ON public.project_votes
    FOR EACH ROW
    EXECUTE FUNCTION check_project_voting_eligibility();
  `);

  // 7. Trigger to automatically increment vote_count on project_submissions when vote cast
  console.log("Setting up vote_count increment trigger...");
  await client.query(`
    CREATE OR REPLACE FUNCTION increment_project_vote_count()
    RETURNS TRIGGER AS $$
    BEGIN
      UPDATE public.project_submissions
      SET vote_count = vote_count + 1
      WHERE id = NEW.project_id;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    DROP TRIGGER IF EXISTS trg_increment_project_vote_count ON public.project_votes;
    CREATE TRIGGER trg_increment_project_vote_count
    AFTER INSERT ON public.project_votes
    FOR EACH ROW
    EXECUTE FUNCTION increment_project_vote_count();
  `);

  // 8. Add tables to supabase_realtime publication
  console.log("Adding tables to supabase_realtime publication...");
  await client.query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'project_submissions'
      ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.project_submissions;
      END IF;

      IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'project_votes'
      ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.project_votes;
      END IF;
    END;
    $$;
  `);

  // 9. Configure Storage Buckets & Policies
  console.log("Configuring storage buckets and policies...");
  await client.query(`
    INSERT INTO storage.buckets (id, name, public) 
    VALUES ('project_assets', 'project_assets', true), ('poll_images', 'poll_images', true)
    ON CONFLICT (id) DO UPDATE SET public = true;
  `);

  // 10. Enable RLS on project_submissions and project_votes
  console.log("Configuring RLS policies...");
  await client.query(`
    ALTER TABLE public.project_submissions ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.project_votes ENABLE ROW LEVEL SECURITY;

    -- Drop existing
    DROP POLICY IF EXISTS "Allow select project_submissions" ON public.project_submissions;
    DROP POLICY IF EXISTS "Allow insert project_submissions" ON public.project_submissions;
    DROP POLICY IF EXISTS "Allow update project_submissions" ON public.project_submissions;
    DROP POLICY IF EXISTS "Allow select project_votes" ON public.project_votes;
    DROP POLICY IF EXISTS "Allow insert project_votes" ON public.project_votes;

    -- project_submissions: Students see only PUBLISHED (admin sees all)
    -- We allow public select for application, but student view filters where status = 'PUBLISHED'
    CREATE POLICY "Allow select project_submissions" ON public.project_submissions
    FOR SELECT TO public USING (true);

    CREATE POLICY "Allow insert project_submissions" ON public.project_submissions
    FOR INSERT TO public WITH CHECK (true);

    CREATE POLICY "Allow update project_submissions" ON public.project_submissions
    FOR UPDATE TO public USING (true) WITH CHECK (true);

    -- project_votes: public can insert their vote (trigger checks eligibility & deadlines)
    CREATE POLICY "Allow insert project_votes" ON public.project_votes
    FOR INSERT TO public WITH CHECK (true);

    CREATE POLICY "Allow select project_votes" ON public.project_votes
    FOR SELECT TO public USING (true);
  `);

  console.log("\n=== MIGRATION COMPLETED SUCCESSFULLY ===");
  await client.end();
}

migrate().catch((err) => {
  console.error("Migration error:", err);
  process.exit(1);
});
