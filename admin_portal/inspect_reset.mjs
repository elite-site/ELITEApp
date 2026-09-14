import pkg from 'pg';
const { Client } = pkg;

const client = new Client({
  connectionString: 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

async function run() {
  await client.connect();
  const tables = await client.query(`
    SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
  `);
  console.log('=== Current Public Tables & Counts ===');
  for (const t of tables.rows) {
    const c = await client.query(`SELECT count(*) FROM public.${t.tablename}`);
    console.log(`${t.tablename.padEnd(25)}: ${c.rows[0].count} rows`);
  }
  
  const authCount = await client.query(`SELECT count(*) FROM auth.users`);
  console.log(`\nauth.users               : ${authCount.rows[0].count} users`);

  const storageCount = await client.query(`SELECT count(*) FROM storage.objects`);
  console.log(`storage.objects          : ${storageCount.rows[0].count} objects`);

  const buckets = await client.query(`SELECT id, name FROM storage.buckets`);
  console.log('storage.buckets          :', buckets.rows.map(b => b.name));

  await client.end();
}

run().catch(console.error);
