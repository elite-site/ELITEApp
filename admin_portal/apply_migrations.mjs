import pkg from 'pg';
const { Client } = pkg;
import fs from 'fs';
import path from 'path';

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

const migrationFiles = [
  '001_initial_schema.sql',
  '002_functions_triggers.sql',
  '003_rls_policies.sql',
  '004_realtime.sql',
  '005_storage.sql',
];

async function applyMigrations() {
  console.log('================================================================');
  console.log('🚀 APPLYING FRESH SUPABASE PRODUCTION MIGRATIONS');
  console.log('================================================================\n');

  const client = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false }
  });

  await client.connect();
  console.log('Connected to Supabase PostgreSQL.\n');

  const migrationsDir = path.resolve('../supabase/migrations');

  for (const file of migrationFiles) {
    const filePath = path.join(migrationsDir, file);
    console.log(`Applying migration: ${file}...`);
    const sql = fs.readFileSync(filePath, 'utf8');

    try {
      await client.query(sql);
      console.log(`   ✅ Migration ${file} applied successfully.\n`);
    } catch (err) {
      console.error(`   ❌ Error in migration ${file}:`, err.message);
      await client.end();
      process.exit(1);
    }
  }

  console.log('================================================================');
  console.log('🎉 ALL MIGRATIONS COMPLETED SUCCESSFULLY');
  console.log('================================================================\n');

  // Verify created tables
  const tables = await client.query(`
    SELECT tablename, rowsecurity 
    FROM pg_tables 
    WHERE schemaname = 'public' 
    ORDER BY tablename;
  `);

  console.log(`Created ${tables.rows.length} production tables in public schema:`);
  console.table(tables.rows);

  await client.end();
}

applyMigrations().catch(console.error);
