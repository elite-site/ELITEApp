import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function seedAdmin() {
  const client = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false }
  });

  await client.connect();

  const adminEmail = 'admin@sasi.ac.in';
  const adminPassword = 'admin123';
  const adminRoll = 'admin';

  // Check if admin already exists
  const existing = await client.query('SELECT id FROM auth.users WHERE email = $1', [adminEmail]);
  let adminId;

  if (existing.rows.length > 0) {
    adminId = existing.rows[0].id;
    await client.query(`UPDATE auth.users SET encrypted_password = crypt($1, gen_salt('bf')) WHERE id = $2`, [adminPassword, adminId]);
  } else {
    const res = await client.query(`
      INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', $1,
        crypt($2, gen_salt('bf')), NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"role":"admin","name":"ELITE Administrator"}'::jsonb,
        NOW(), NOW()
      ) RETURNING id;
    `, [adminEmail, adminPassword]);
    adminId = res.rows[0].id;
  }

  // Insert or update profile
  await client.query(`
    INSERT INTO public.profiles (
      id, roll_number, full_name, email, department, role, is_active, created_at, updated_at
    ) VALUES (
      $1, $2, 'ELITE Administrator', $3, 'Information Technology', 'admin', true, NOW(), NOW()
    ) ON CONFLICT (id) DO UPDATE SET
      roll_number = EXCLUDED.roll_number,
      role = 'admin',
      is_active = true;
  `, [adminId, adminRoll, adminEmail]);

  console.log('✅ Fresh verified Admin account created:');
  console.log(`   User ID:   ${adminId}`);
  console.log(`   Roll/User: ${adminRoll}`);
  console.log(`   Password:  ${adminPassword}`);
  console.log(`   Email:     ${adminEmail}`);
  console.log(`   Role:      admin`);

  await client.end();
}

seedAdmin().catch(console.error);
