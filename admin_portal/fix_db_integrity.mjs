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

  // 1. Fix Foreign Key constraints to avoid cascade blocks when deleting events or users
  console.log("Updating foreign key constraints...");

  // notifications_target_event_id_fkey -> ON DELETE SET NULL
  await client.query(`
    ALTER TABLE public.notifications 
    DROP CONSTRAINT IF EXISTS notifications_target_event_id_fkey;
    
    ALTER TABLE public.notifications 
    ADD CONSTRAINT notifications_target_event_id_fkey 
    FOREIGN KEY (target_event_id) REFERENCES public.events(id) ON DELETE SET NULL;
  `);

  // events_created_by_fkey -> ON DELETE SET NULL
  await client.query(`
    ALTER TABLE public.events 
    DROP CONSTRAINT IF EXISTS events_created_by_fkey;
    
    ALTER TABLE public.events 
    ADD CONSTRAINT events_created_by_fkey 
    FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;
  `);

  // polls_created_by_fkey -> ON DELETE SET NULL
  await client.query(`
    ALTER TABLE public.polls 
    DROP CONSTRAINT IF EXISTS polls_created_by_fkey;
    
    ALTER TABLE public.polls 
    ADD CONSTRAINT polls_created_by_fkey 
    FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;
  `);

  // project_submissions_leader_id_fkey -> ON DELETE CASCADE
  await client.query(`
    ALTER TABLE public.project_submissions 
    DROP CONSTRAINT IF EXISTS project_submissions_leader_id_fkey;
    
    ALTER TABLE public.project_submissions 
    ADD CONSTRAINT project_submissions_leader_id_fkey 
    FOREIGN KEY (leader_id) REFERENCES public.users(id) ON DELETE CASCADE;
  `);

  console.log("Foreign keys successfully updated.");

  // 2. Grant full CRUD RLS policies on project_submissions and project_votes
  console.log("Updating RLS policies for project_submissions and project_votes...");

  await client.query(`
    DROP POLICY IF EXISTS "Allow delete project_submissions" ON public.project_submissions;
    CREATE POLICY "Allow delete project_submissions" ON public.project_submissions 
    FOR DELETE TO public USING (true);

    DROP POLICY IF EXISTS "Allow update project_votes" ON public.project_votes;
    CREATE POLICY "Allow update project_votes" ON public.project_votes 
    FOR UPDATE TO public USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow delete project_votes" ON public.project_votes;
    CREATE POLICY "Allow delete project_votes" ON public.project_votes 
    FOR DELETE TO public USING (true);
  `);

  // Also ensure profiles has DELETE policy
  await client.query(`
    DROP POLICY IF EXISTS "Allow delete profiles" ON public.profiles;
    CREATE POLICY "Allow delete profiles" ON public.profiles 
    FOR DELETE TO public USING (true);
    
    DROP POLICY IF EXISTS "Allow insert profiles" ON public.profiles;
    CREATE POLICY "Allow insert profiles" ON public.profiles 
    FOR INSERT TO public WITH CHECK (true);
  `);

  console.log("RLS policies successfully updated.");

  await client.end();
  console.log("Migration complete!");
}

migrate().catch(err => {
  console.error("Migration error:", err);
  process.exit(1);
});
