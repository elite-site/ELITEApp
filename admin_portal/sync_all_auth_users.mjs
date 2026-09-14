import pg from 'pg';

const client = new pg.Client({
  connectionString: 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

async function syncAllAuthUsers() {
  await client.connect();
  console.log('Connected to Supabase Postgres. Starting full auth.users synchronization...');

  // 1. Get all students
  const studentsRes = await client.query(`
    SELECT user_id, roll_no, password_hash 
    FROM public.students;
  `);
  console.log(`Found ${studentsRes.rows.length} students to sync.`);

  // 2. Get all staff
  const staffRes = await client.query(`
    SELECT user_id, employee_id, username, password_hash 
    FROM public.staff;
  `);
  console.log(`Found ${staffRes.rows.length} staff to sync.`);

  // 3. Get all admins
  const adminRes = await client.query(`
    SELECT id, username, password_hash, email 
    FROM public.users 
    WHERE role IN ('SUPER_ADMIN', 'ADMIN');
  `);
  console.log(`Found ${adminRes.rows.length} admins to sync.`);

  // Function to create or update auth user
  const syncUser = async (uuid, email, password) => {
    // Delete existing identity and user if needed to ensure clean state
    await client.query(`DELETE FROM auth.identities WHERE email = $1;`, [email]);
    await client.query(`DELETE FROM auth.users WHERE email = $1;`, [email]);

    // Insert into auth.users
    await client.query(`
      INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at,
        email_change_token_new, email_change, email_change_sent_at, last_sign_in_at,
        raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at,
        phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at,
        email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token,
        reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous
      ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        $1::uuid,
        'authenticated',
        'authenticated',
        $2::character varying,
        crypt($3, gen_salt('bf', 10)),
        NOW(),
        null, '', null, null, null,
        null, null, null, null,
        '{"provider":"email","providers":["email"]}',
        jsonb_build_object('sub', $1::text, 'email', $2::character varying),
        null, NOW(), NOW(),
        null, null, '', '', null,
        '', 0, null, '',
        null, false, null, false
      );
    `, [uuid, email, password]);

    // Insert into auth.identities
    await client.query(`
      INSERT INTO auth.identities (
        id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
      ) VALUES (
        gen_random_uuid(),
        $1::text,
        $1::uuid,
        jsonb_build_object('sub', $1::text, 'email', $2::character varying),
        'email',
        NOW(), NOW(), NOW()
      );
    `, [uuid, email]);
  };

  // Sync Admins
  let adminCount = 0;
  for (const a of adminRes.rows) {
    const email = (a.email && a.email.includes('@')) ? a.email.toLowerCase().trim() : `${a.username.toLowerCase()}@sasi.ac.in`;
    const pwd = a.password_hash || 'admin123';
    // Generate deterministic UUID for admin
    const adminUuid = a.id === 'u_admin' 
      ? 'a0000000-0000-0000-0000-000000000001'
      : (a.id === 'u_admin_001' 
          ? 'a0000000-0000-0000-0000-000000000002' 
          : 'a0000000-0000-0000-0000-000000000003');
    await syncUser(adminUuid, email, pwd);
    adminCount++;
  }
  console.log(`✓ Synced ${adminCount} admins.`);

  // Sync Staff
  let staffCount = 0;
  for (let i = 0; i < staffRes.rows.length; i++) {
    const s = staffRes.rows[i];
    const email = s.username ? `${s.username.toLowerCase().trim()}@sasi.ac.in` : `${s.employee_id.toLowerCase().trim()}@sasi.ac.in`;
    const pwd = s.password_hash || s.username || 'hod_it';
    const num = (i + 1).toString().padStart(12, '0');
    const staffUuid = `b0000000-0000-0000-0000-${num}`;
    await syncUser(staffUuid, email, pwd);
    staffCount++;
  }
  console.log(`✓ Synced ${staffCount} staff.`);

  // Sync Students
  let studentCount = 0;
  for (let i = 0; i < studentsRes.rows.length; i++) {
    const stu = studentsRes.rows[i];
    const email = `${stu.roll_no.toLowerCase().trim()}@sasi.ac.in`;
    const pwd = stu.password_hash || stu.roll_no.toLowerCase().trim();
    const num = (i + 1).toString().padStart(12, '0');
    const studentUuid = `c0000000-0000-0000-0000-${num}`;
    await syncUser(studentUuid, email, pwd);
    studentCount++;
    if (studentCount % 100 === 0) {
      console.log(`  Processed ${studentCount} students...`);
    }
  }
  console.log(`✓ Synced all ${studentCount} students.`);

  console.log('\n=== ALL USERS SYNCHRONIZED INTO auth.users & auth.identities ===');
  await client.end();
}

syncAllAuthUsers().catch(e => {
  console.error('Sync failed:', e);
  process.exit(1);
});
