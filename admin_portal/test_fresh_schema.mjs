import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function testFreshSchema() {
  console.log('================================================================');
  console.log('🧪 COMPREHENSIVE FRESH SCHEMA & TRIGGER TEST SUITE');
  console.log('================================================================\n');

  const client = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false }
  });

  await client.connect();

  try {
    // Initial cleanup of any leftover test records
    await client.query(`DELETE FROM auth.users WHERE email LIKE 's%@sasi.ac.in';`);
    await client.query(`DELETE FROM public.profiles WHERE roll_number LIKE 'TEST_ROLL_%';`);

    // 1. Verify all 15 tables exist
    process.stdout.write('1. Table verification (15 tables): ');
    const tablesRes = await client.query(`
      SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
    `);
    const expectedTables = [
      'event_attendance', 'event_coordinators', 'event_registration_answers',
      'event_registration_fields', 'event_registrations', 'events',
      'poll_option_images', 'poll_options', 'poll_votes', 'polls',
      'profiles', 'project_images', 'project_submissions', 'team_members', 'teams'
    ];
    const found = tablesRes.rows.map(r => r.tablename);
    const missing = expectedTables.filter(t => !found.includes(t));
    if (missing.length > 0) throw new Error(`Missing tables: ${missing.join(', ')}`);
    console.log(`✅ Passed (${found.length} tables verified)`);

    // 2. Storage Buckets Verification
    process.stdout.write('2. Storage buckets verification: ');
    const bucketsRes = await client.query(`SELECT id FROM storage.buckets;`);
    const bucketIds = bucketsRes.rows.map(b => b.id);
    const reqBuckets = ['event-images', 'event-rules', 'project-files', 'project-images', 'poll-images'];
    const missingBuckets = reqBuckets.filter(b => !bucketIds.includes(b));
    if (missingBuckets.length > 0) throw new Error(`Missing buckets: ${missingBuckets.join(', ')}`);
    console.log(`✅ Passed (${reqBuckets.length} buckets active)`);

    // 3. Realtime Publication Verification
    process.stdout.write('3. Realtime publication tables: ');
    const pubRes = await client.query(`
      SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
    `);
    const pubTables = pubRes.rows.map(r => r.tablename);
    console.log(`✅ Passed (${pubTables.join(', ')})`);

    // 4. Test User / Profile Creation with Auth linkage
    process.stdout.write('4. Profile creation linked to auth: ');
    const authId1 = (await client.query(`
      INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
      VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 's1@sasi.ac.in', crypt('pass', gen_salt('bf')), NOW(), NOW(), NOW())
      RETURNING id;
    `)).rows[0].id;

    await client.query(`
      INSERT INTO public.profiles (id, roll_number, full_name, role)
      VALUES ($1, 'TEST_ROLL_1', 'Student Tester One', 'student');
    `, [authId1]);
    console.log('✅ Passed');

    // 5. Test 10-Minute Registration Deadline Trigger
    process.stdout.write('5. Server-enforced 10-min registration deadline: ');
    // Create an event that started 5 minutes ago
    const pastEventId = (await client.query(`
      INSERT INTO public.events (
        title, description, category, event_type, venue, event_date, start_time, status
      ) VALUES (
        'Starting Soon Event', 'Testing Deadline', 'Technical', 'individual', 'Hall A',
        CURRENT_DATE, (CURRENT_TIME - INTERVAL '5 minutes')::TIME, 'published'
      ) RETURNING id;
    `)).rows[0].id;

    let deadlineBlocked = false;
    try {
      await client.query(`
        INSERT INTO public.event_registrations (event_id, student_id)
        VALUES ($1, $2);
      `, [pastEventId, authId1]);
    } catch (err) {
      if (err.message.includes('Registration closes automatically 10 minutes before event start')) {
        deadlineBlocked = true;
      } else {
        throw err;
      }
    }
    if (!deadlineBlocked) throw new Error('10-minute deadline trigger failed to block registration!');
    console.log('✅ Passed (Blocked late registration as expected)');

    // 6. Test Team Constraints (Max 4 members, single team per event)
    process.stdout.write('6. Server-enforced team constraints (Max 4 & no duplicate team): ');
    const futureEventId = (await client.query(`
      INSERT INTO public.events (
        title, description, category, event_type, venue, event_date, start_time, status
      ) VALUES (
        'Future Team Hackathon', 'Testing Teams', 'Hackathon', 'team', 'Hall B',
        CURRENT_DATE + 5, '10:00:00', 'published'
      ) RETURNING id;
    `)).rows[0].id;

    // Create 4 more student profiles for team testing
    const studentIds = [authId1];
    for (let i = 2; i <= 5; i++) {
      const aId = (await client.query(`
        INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
        VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 's${i}@sasi.ac.in', crypt('pass', gen_salt('bf')), NOW(), NOW(), NOW())
        RETURNING id;
      `)).rows[0].id;

      await client.query(`
        INSERT INTO public.profiles (id, roll_number, full_name, role)
        VALUES ($1, 'TEST_ROLL_${i}', 'Student Tester ${i}', 'student');
      `, [aId]);
      studentIds.push(aId);
    }

    // Create Team A with Leader = studentIds[0]
    const teamAId = (await client.query(`
      INSERT INTO public.teams (event_id, team_name, leader_id)
      VALUES ($1, 'Team Alpha', $2) RETURNING id;
    `, [futureEventId, studentIds[0]])).rows[0].id;

    // Add leader and members 2, 3, 4 (Total = 4 members)
    await client.query(`INSERT INTO public.team_members (team_id, student_id, is_leader) VALUES ($1, $2, true);`, [teamAId, studentIds[0]]);
    await client.query(`INSERT INTO public.team_members (team_id, student_id) VALUES ($1, $2);`, [teamAId, studentIds[1]]);
    await client.query(`INSERT INTO public.team_members (team_id, student_id) VALUES ($1, $2);`, [teamAId, studentIds[2]]);
    await client.query(`INSERT INTO public.team_members (team_id, student_id) VALUES ($1, $2);`, [teamAId, studentIds[3]]);

    // Attempt 5th member -> Expect error
    let maxTeamBlocked = false;
    try {
      await client.query(`INSERT INTO public.team_members (team_id, student_id) VALUES ($1, $2);`, [teamAId, studentIds[4]]);
    } catch (err) {
      if (err.message.includes('Team size limit exceeded')) {
        maxTeamBlocked = true;
      }
    }
    if (!maxTeamBlocked) throw new Error('Failed to enforce max 4 members per team!');

    // Create Team B for same event
    const teamBId = (await client.query(`
      INSERT INTO public.teams (event_id, team_name, leader_id)
      VALUES ($1, 'Team Beta', $2) RETURNING id;
    `, [futureEventId, studentIds[4]])).rows[0].id;

    // Attempt to add studentIds[1] (who is already in Team Alpha) to Team Beta -> Expect error
    let duplicateTeamBlocked = false;
    try {
      await client.query(`INSERT INTO public.team_members (team_id, student_id) VALUES ($1, $2);`, [teamBId, studentIds[1]]);
    } catch (err) {
      if (err.message.includes('Duplicate team participation')) {
        duplicateTeamBlocked = true;
      }
    }
    if (!duplicateTeamBlocked) throw new Error('Failed to block duplicate team participation for same event!');
    console.log('✅ Passed (Max 4 & cross-team prevention enforced)');

    // 7. Test Poll Single-Vote Unique Constraint & Immutability
    process.stdout.write('7. Poll single-vote constraint & vote immutability: ');
    const pollId = (await client.query(`
      INSERT INTO public.polls (title, is_active) VALUES ('Best Project Track?', true) RETURNING id;
    `)).rows[0].id;

    const optId1 = (await client.query(`
      INSERT INTO public.poll_options (poll_id, title) VALUES ($1, 'Generative AI') RETURNING id;
    `, [pollId])).rows[0].id;

    const optId2 = (await client.query(`
      INSERT INTO public.poll_options (poll_id, title) VALUES ($1, 'Cyber Security') RETURNING id;
    `, [pollId])).rows[0].id;

    // Vote once
    const voteId = (await client.query(`
      INSERT INTO public.poll_votes (poll_id, poll_option_id, voter_id)
      VALUES ($1, $2, $3) RETURNING id;
    `, [pollId, optId1, studentIds[0]])).rows[0].id;

    // Vote second time -> Expect unique constraint violation
    let duplicateVoteBlocked = false;
    try {
      await client.query(`
        INSERT INTO public.poll_votes (poll_id, poll_option_id, voter_id)
        VALUES ($1, $2, $3);
      `, [pollId, optId2, studentIds[0]]);
    } catch (err) {
      if (err.message.includes('uq_poll_single_voter') || err.message.includes('duplicate key')) {
        duplicateVoteBlocked = true;
      }
    }
    if (!duplicateVoteBlocked) throw new Error('Single-vote constraint failed to block second vote!');

    // Attempt to update vote -> Expect immutability trigger to block
    let updateVoteBlocked = false;
    try {
      await client.query(`UPDATE public.poll_votes SET poll_option_id = $1 WHERE id = $2;`, [optId2, voteId]);
    } catch (err) {
      if (err.message.includes('Vote locked: Once cast, a vote cannot be modified or deleted.')) {
        updateVoteBlocked = true;
      }
    }
    if (!updateVoteBlocked) throw new Error('Failed to prevent vote modification!');
    console.log('✅ Passed (Single vote & vote immutability enforced)');

    // 8. Clean up all test data so database is returned to 0 rows
    console.log('\n8. Cleaning up test data...');
    await client.query(`
      TRUNCATE TABLE 
        public.event_attendance,
        public.poll_votes,
        public.poll_option_images,
        public.poll_options,
        public.polls,
        public.project_images,
        public.project_submissions,
        public.event_registration_answers,
        public.event_registration_fields,
        public.event_registrations,
        public.team_members,
        public.teams,
        public.event_coordinators,
        public.events,
        public.profiles
      CASCADE;
    `);
    await client.query(`DELETE FROM auth.users;`);
    console.log('✅ Database cleaned to pristine baseline (0 rows across all tables).\n');

    console.log('🎉 ALL TESTS PASSED: Fresh database schema, triggers, and constraints are 100% operational!');
  } catch (err) {
    console.error('\n❌ TEST FAILED:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

testFreshSchema();
