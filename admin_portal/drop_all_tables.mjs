import pkg from 'pg';
const { Client } = pkg;
import fs from 'fs';

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function exportAndDropTables() {
  const client = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false }
  });

  await client.connect();
  console.log('Connected to Supabase PostgreSQL.\n');

  // 1. Get all tables in public schema
  const tablesRes = await client.query(`
    SELECT tablename 
    FROM pg_tables 
    WHERE schemaname = 'public' 
    ORDER BY tablename;
  `);
  const tables = tablesRes.rows.map(r => r.tablename);
  console.log(`Found ${tables.length} tables in public schema:`, tables);

  if (tables.length === 0) {
    console.log('No tables found in public schema.');
    await client.end();
    return;
  }

  // 2. Drop all tables with CASCADE
  console.log('\nDropping all tables with CASCADE...');
  for (const t of tables) {
    await client.query(`DROP TABLE IF EXISTS public."${t}" CASCADE;`);
    console.log(`   🗑️ Dropped table: public.${t}`);
  }

  // 3. Verify that public schema now has 0 tables
  const verifyRes = await client.query(`
    SELECT tablename 
    FROM pg_tables 
    WHERE schemaname = 'public' 
    ORDER BY tablename;
  `);

  console.log(`\nVerification: ${verifyRes.rows.length} tables remaining in public schema.`);
  if (verifyRes.rows.length > 0) {
    console.table(verifyRes.rows);
  } else {
    console.log('✅ ALL tables have been completely removed from the database.');
  }

  await client.end();
}

exportAndDropTables().catch(console.error);
