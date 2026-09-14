import fs from 'fs';
import path from 'path';
import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function applyMigration() {
  console.log('================================================================');
  console.log('⚡ APPLYING MIGRATION 007: USER SESSIONS & REALTIME PRESENCE');
  console.log('================================================================\n');

  const migrationPath = path.resolve('..', 'supabase', 'migrations', '007_user_sessions.sql');
  console.log(`📖 Reading migration file: ${migrationPath}`);
  const sql = fs.readFileSync(migrationPath, 'utf8');

  const client = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false }
  });

  await client.connect();
  console.log('🔌 Connected to Supabase PostgreSQL.\n');

  try {
    await client.query('BEGIN');
    await client.query(sql);
    await client.query('COMMIT');
    console.log('✅ Migration 007 applied successfully!');

    // Verify table
    const checkRes = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'user_sessions'
      ORDER BY ordinal_position;
    `);
    console.log('\n📊 Created public.user_sessions columns:');
    console.table(checkRes.rows);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Failed to apply migration 007:', err);
    throw err;
  } finally {
    await client.end();
  }
}

applyMigration().catch((err) => {
  console.error(err);
  process.exit(1);
});
