import pkg from 'pg';
const { Client } = pkg;
import fs from 'fs';
import path from 'path';

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function applyMigration() {
  const client = new Client({ connectionString: CONN, ssl: { rejectUnauthorized: false } });
  await client.connect();
  console.log('Connected to Supabase PostgreSQL database.');

  const sqlPath = path.resolve('../supabase/migrations/006_event_coordinators_and_date.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');

  console.log('Applying Migration 006...');
  await client.query(sql);
  console.log('✅ Migration 006 applied successfully!');

  await client.end();
}

applyMigration().catch(console.error);
