import pkg from 'pg';
const { Client } = pkg;
import fs from 'fs';

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function backupSchema() {
  const client = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false }
  });

  await client.connect();

  const tables = await client.query(`
    SELECT tablename 
    FROM pg_tables 
    WHERE schemaname = 'public' 
    ORDER BY tablename;
  `);

  let ddl = '-- ====================================================\n';
  ddl += '-- BACKUP OF ALL PUBLIC TABLES BEFORE DROP\n';
  ddl += `-- Exported at: ${new Date().toISOString()}\n`;
  ddl += '-- ====================================================\n\n';

  for (const t of tables.rows) {
    const tableName = t.tablename;
    const cols = await client.query(`
      SELECT column_name, data_type, udt_name, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1
      ORDER BY ordinal_position;
    `, [tableName]);

    ddl += `CREATE TABLE IF NOT EXISTS public."${tableName}" (\n`;
    const colDefs = cols.rows.map(c => {
      let def = `  "${c.column_name}" ${c.data_type === 'USER-DEFINED' ? c.udt_name : c.data_type}`;
      if (c.is_nullable === 'NO') def += ' NOT NULL';
      if (c.column_default) def += ` DEFAULT ${c.column_default}`;
      return def;
    });
    ddl += colDefs.join(',\n');
    ddl += '\n);\n\n';
  }

  fs.writeFileSync('schema_backup.sql', ddl);
  console.log('Schema backup saved to admin_portal/schema_backup.sql');

  await client.end();
}

backupSchema().catch(console.error);
