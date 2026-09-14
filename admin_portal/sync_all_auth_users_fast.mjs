import pg from 'pg';

const client = new pg.Client({
  connectionString: 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

async function runFastSync() {
  await client.connect();
  console.log('Connected to Supabase Postgres. Starting instant set-based synchronization...');

  console.log('1. Clearing existing auth tables...');
  await client.query(`DELETE FROM auth.identities;`);
  await client.query(`DELETE FROM auth.sessions;`);
  await client.query(`DELETE FROM auth.users;`);
  console.log('   ✓ Cleared auth tables.');

  // 1. Admins
  console.log('2. Syncing admins...');
  await client.query(`
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      'a0000000-0000-0000-0000-000000000001'::uuid,
      'authenticated', 'authenticated',
      'admin@sasi.ac.in', crypt('admin123', gen_salt('bf', 10)), NOW(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('sub', 'a0000000-0000-0000-0000-000000000001', 'email', 'admin@sasi.ac.in'),
      true, NOW(), NOW()
    ), (
      '00000000-0000-0000-0000-000000000000',
      'a0000000-0000-0000-0000-000000000002'::uuid,
      'authenticated', 'authenticated',
      'admin123@sasi.ac.in', crypt('123@admin', gen_salt('bf', 10)), NOW(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('sub', 'a0000000-0000-0000-0000-000000000002', 'email', 'admin123@sasi.ac.in'),
      true, NOW(), NOW()
    );
  `);

  // 2. Staff
  console.log('3. Syncing staff...');
  await client.query(`
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      'b0000000-0000-0000-0000-000000000001'::uuid,
      'authenticated', 'authenticated',
      'hod_it@sasi.ac.in', crypt('hod_it', gen_salt('bf', 10)), NOW(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('sub', 'b0000000-0000-0000-0000-000000000001', 'email', 'hod_it@sasi.ac.in'),
      false, NOW(), NOW()
    ), (
      '00000000-0000-0000-0000-000000000000',
      'b0000000-0000-0000-0000-000000000002'::uuid,
      'authenticated', 'authenticated',
      'staff01@sasi.ac.in', crypt('staff01', gen_salt('bf', 10)), NOW(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('sub', 'b0000000-0000-0000-0000-000000000002', 'email', 'staff01@sasi.ac.in'),
      false, NOW(), NOW()
    );
  `);

  // 3. All students via single set-based SQL
  console.log('4. Syncing all students (single batch query)...');
  const stuRes = await client.query(`
    WITH student_data AS (
      SELECT 
        ('c0000000-0000-0000-0000-' || LPAD(ROW_NUMBER() OVER (ORDER BY roll_no)::text, 12, '0'))::uuid AS uid,
        (LOWER(roll_no) || '@sasi.ac.in')::character varying AS uemail,
        crypt(COALESCE(password_hash, LOWER(roll_no)), gen_salt('bf', 10)) AS upass
      FROM public.students
    )
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at
    )
    SELECT
      '00000000-0000-0000-0000-000000000000',
      uid,
      'authenticated',
      'authenticated',
      uemail,
      upass,
      NOW(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('sub', uid::text, 'email', uemail),
      false,
      NOW(),
      NOW()
    FROM student_data;
  `);
  console.log(`   ✓ Students processed, rows inserted: ${stuRes.rowCount}`);

  // 4. Update auth.identities for all users in auth.users
  console.log('5. Syncing auth.identities for all accounts...');
  const identRes = await client.query(`
    INSERT INTO auth.identities (
      id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    )
    SELECT
      gen_random_uuid(),
      id::text,
      id,
      jsonb_build_object('sub', id::text, 'email', email),
      'email',
      NOW(), NOW(), NOW()
    FROM auth.users;
  `);
  console.log(`   ✓ Identities processed, rows inserted: ${identRes.rowCount}`);

  // Check total in auth.users
  const total = await client.query(`SELECT count(*) FROM auth.users;`);
  console.log(`\n🎉 Total authenticated users in auth.users: ${total.rows[0].count}`);

  await client.end();
}

runFastSync().catch(e => {
  console.error('Fast sync error:', e);
  process.exit(1);
});
