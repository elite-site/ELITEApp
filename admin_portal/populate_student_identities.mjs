import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function syncIdentities() {
  console.log('================================================================');
  console.log('🔄 SYNCING AUTH.IDENTITIES AND TOKENS FOR ALL 404 STUDENTS');
  console.log('================================================================\n');

  const client = new Client({ connectionString: CONN, ssl: { rejectUnauthorized: false } });
  await client.connect();

  // 1. Ensure all auth.users have non-null token strings for GoTrue scanner
  console.log('1. Setting non-null tokens in auth.users...');
  const tokenRes = await client.query(`
    UPDATE auth.users
    SET confirmation_token = COALESCE(confirmation_token, ''),
        recovery_token = COALESCE(recovery_token, ''),
        email_change_token_new = COALESCE(email_change_token_new, ''),
        email_change = COALESCE(email_change, '')
    WHERE confirmation_token IS NULL
       OR recovery_token IS NULL
       OR email_change_token_new IS NULL
       OR email_change IS NULL;
  `);
  console.log(`   Updated ${tokenRes.rowCount} users with clean token strings.`);

  // 2. Insert missing identities for all users
  console.log('2. Inserting missing auth.identities for all users...');
  const identRes = await client.query(`
    INSERT INTO auth.identities (
      id, provider_id, user_id, identity_data, provider, created_at, updated_at
    )
    SELECT
      gen_random_uuid(),
      u.id::text,
      u.id,
      json_build_object('sub', u.id::text, 'email', u.email::text),
      'email',
      NOW(),
      NOW()
    FROM auth.users u
    LEFT JOIN auth.identities i ON u.id = i.user_id AND i.provider = 'email'
    WHERE i.id IS NULL
    ON CONFLICT (provider_id, provider) DO NOTHING;
  `);
  console.log(`   Inserted ${identRes.rowCount} missing identities into auth.identities.`);

  const totalIdentities = await client.query('SELECT count(*) FROM auth.identities');
  const totalUsers = await client.query('SELECT count(*) FROM auth.users');
  console.log(`\n📊 Total Users in auth.users:      ${totalUsers.rows[0].count}`);
  console.log(`📊 Total Identities in auth.ident: ${totalIdentities.rows[0].count}`);

  await client.end();
  console.log('\n✅ All identities and tokens successfully synchronized!');
}

syncIdentities().catch(console.error);
