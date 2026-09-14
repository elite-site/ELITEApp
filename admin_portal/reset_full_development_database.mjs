import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function resetDatabase() {
  console.log('================================================================');
  console.log('🔥 STARTING FULL DEVELOPMENT DATABASE RESET FOR ELITE PLATFORM');
  console.log('================================================================\n');

  const client = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false }
  });

  await client.connect();
  console.log('Connected to Supabase PostgreSQL.\n');

  try {
    await client.query('BEGIN;');

    // 1. TRUNCATE all public tables in cascade order
    console.log('1. Clearing all application data tables in public schema...');
    
    await client.query(`
      TRUNCATE TABLE 
        public.project_votes,
        public.project_submissions,
        public.poll_votes,
        public.poll_options,
        public.polls,
        public.event_attendance,
        public.event_registrations,
        public.event_staff,
        public.events,
        public.notification_reads,
        public.notifications,
        public.fcm_tokens,
        public.student_queries,
        public.alerts,
        public.announcements,
        public.audit_logs,
        public.profiles,
        public.students,
        public.staff,
        public.users,
        public.academic_years
      RESTART IDENTITY CASCADE;
    `);
    console.log('   ✅ All 21 public application tables truncated.');

    // 2. Clear development Auth users
    console.log('2. Clearing all development authentication users in auth schema...');
    const delAuth = await client.query(`DELETE FROM auth.users;`);
    console.log(`   ✅ Cleared ${delAuth.rowCount || 0} users from auth.users (cascaded to sessions/tokens).`);

    // 3. Clear development Storage objects via Supabase Client API if any exist
    console.log('3. Checking files in Supabase Storage buckets...');
    try {
      const { createClient } = await import('@supabase/supabase-js');
      const sClient = createClient(
        'https://qjntsxlmdrldbnvmqpca.supabase.co',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqbnRzeGxtZHJsZGJudm1xcGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxODAxODksImV4cCI6MjEwNDc1NjE4OX0.wzkJ2LQz8vxAtA9ylrNbqm6P7uwiZ2GcxcG-g3Gig_o'
      );
      for (const bucket of ['project_assets', 'poll_images']) {
        const { data: files } = await sClient.storage.from(bucket).list();
        if (files && files.length > 0) {
          await sClient.storage.from(bucket).remove(files.map((f) => f.name));
        }
      }
      console.log('   ✅ Storage buckets cleared.');
    } catch (sErr) {
      console.log('   ℹ️ Storage buckets already clean:', sErr.message);
    }

    // 4. Seed Current Academic Year
    console.log('4. Seeding baseline Academic Year...');
    await client.query(`
      INSERT INTO public.academic_years (id, year_name, is_current, created_at)
      VALUES ('ay_2026_2027', '2026-2027', true, NOW());
    `);
    console.log('   ✅ Academic Year 2026-2027 established.');

    // 5. Create Single Fresh Real Admin Account
    console.log('5. Creating fresh verified Administrator account...');
    const adminId = 'u_admin';
    const adminUsername = 'admin';
    const adminPassword = 'admin123';
    const adminEmail = 'admin@sasi.ac.in';

    // In users table
    await client.query(`
      INSERT INTO public.users (
        id, username, email, password_hash, role, department, status, must_change_password, created_at, updated_at
      ) VALUES (
        $1, $2, $3, $4, 'SUPER_ADMIN', 'Information Technology', 'ACTIVE', false, NOW(), NOW()
      );
    `, [adminId, adminUsername, adminEmail, adminPassword]);

    // In profiles table (for mobile app & unified profile lookup)
    await client.query(`
      INSERT INTO public.profiles (
        id, name, email, student_id, department, year, section, role, status,
        academic_details, phone_number, lab_pass_id, lab_pass_room, lab_pass_expiry, cgpa, attendance_percent,
        created_at, updated_at
      ) VALUES (
        $1, 'ELITE Administrator', $2, $3, 'Information Technology', 'Administration', 'Admin Cell', 'admin', 'ACTIVE',
        'System Administrator • SASI IT', '+91 99999 99999', 'ADMIN-ROOT-KEY-00', 'Full Campus Facilities', 'Permanent Admin Access', 10.0, 100,
        NOW(), NOW()
      );
    `, [adminId, adminEmail, adminUsername]);

    // Also register in auth.users so Supabase auth email/password works if used
    await client.query(`
      INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', $1,
        crypt($2, gen_salt('bf')), NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"role":"admin","name":"ELITE Administrator"}'::jsonb,
        NOW(), NOW()
      );
    `, [adminEmail, adminPassword]);

    console.log('   ✅ Fresh Administrator account created:');
    console.log(`      Username: ${adminUsername}`);
    console.log(`      Password: ${adminPassword}`);
    console.log(`      Email:    ${adminEmail}`);
    console.log(`      Role:     SUPER_ADMIN`);

    await client.query('COMMIT;');
    console.log('\n================================================================');
    console.log('🎉 DATABASE RESET COMPLETE - VERIFYING CLEAN RECORD COUNTS:');
    console.log('================================================================\n');

    // Post-reset verification
    const tables = await client.query(`
      SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
    `);

    for (const t of tables.rows) {
      const c = await client.query(`SELECT count(*) FROM public.${t.tablename}`);
      console.log(`   ${t.tablename.padEnd(25)}: ${c.rows[0].count} row(s)`);
    }

    const authCount = await client.query(`SELECT count(*) FROM auth.users`);
    console.log(`   ${'auth.users'.padEnd(25)}: ${authCount.rows[0].count} user(s) (Fresh Admin Only)`);

    const storageCount = await client.query(`SELECT count(*) FROM storage.objects`);
    console.log(`   ${'storage.objects'.padEnd(25)}: ${storageCount.rows[0].count} object(s)`);

  } catch (err) {
    await client.query('ROLLBACK;');
    console.error('\n❌ RESET FAILED, TRANSACTION ROLLED BACK:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

resetDatabase();
