import pkg from 'pg';
const { Client } = pkg;
import readline from 'readline';

const DEFAULT_CONN = 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

let args = process.argv.slice(2);
let connectionString = DEFAULT_CONN;

// If first arg is a connection URI
if (args[0] && (args[0].startsWith('postgres://') || args[0].startsWith('postgresql://'))) {
  connectionString = args[0];
  args = args.slice(1);
}

// Strip -c flag if user typed psql -c "..."
if (args[0] === '-c') {
  args = args.slice(1);
}

const directQuery = args.join(' ').trim();

async function main() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
  } catch (err) {
    console.error("\n[PostgreSQL Connection Error]:", err.message);
    console.error("Please verify network connection and database credentials.\n");
    process.exit(1);
  }

  // If a direct query was provided via CLI argument:
  if (directQuery) {
    try {
      console.log(`\n[Executing on Supabase Postgres] > ${directQuery}\n`);
      const res = await client.query(directQuery);
      if (res.rows && res.rows.length > 0) {
        console.table(res.rows);
        console.log(`\n(${res.rows.length} row(s) returned)\n`);
      } else {
        console.log(`Command: ${res.command} | Affected rows: ${res.rowCount || 0}\n`);
      }
    } catch (err) {
      console.error("[SQL Error]:", err.message);
    } finally {
      await client.end();
      process.exit(0);
    }
    return;
  }

  // Interactive REPL Shell Mode
  console.log("\n" + "=".repeat(75));
  console.log("  🐘 ELITE PostgreSQL Interactive Shell");
  console.log("  Host: aws-0-ap-northeast-1.pooler.supabase.com (Port: 5432)");
  console.log("  Database: postgres | User: postgres.qjntsxlmdrldbnvmqpca");
  console.log("=".repeat(75));
  console.log("  Commands:");
  console.log("    \\dt                 - List all tables in public schema");
  console.log("    \\d <table_name>     - Describe columns of a table");
  console.log("    \\q or exit          - Disconnect and exit shell");
  console.log("  Or type any valid SQL query (e.g. SELECT count(*) FROM students;)\n");

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    prompt: 'postgres=> '
  });

  rl.prompt();

  let multilineBuffer = '';

  rl.on('line', async (line) => {
    const trimmed = line.trim();

    if (!trimmed) {
      rl.prompt();
      return;
    }

    if (trimmed === '\\q' || trimmed.toLowerCase() === 'exit' || trimmed.toLowerCase() === 'quit') {
      console.log("\nDisconnecting from database. Goodbye!");
      await client.end();
      process.exit(0);
    }

    if (trimmed === '\\dt') {
      try {
        const res = await client.query(`
          SELECT table_name, table_type 
          FROM information_schema.tables 
          WHERE table_schema = 'public' 
          ORDER BY table_name;
        `);
        console.table(res.rows);
        console.log(`(${res.rows.length} tables in public schema)\n`);
      } catch (e) {
        console.error("Error:", e.message);
      }
      rl.prompt();
      return;
    }

    if (trimmed.startsWith('\\d ')) {
      const tbl = trimmed.slice(3).trim().replace(/['";]/g, '');
      try {
        const res = await client.query(`
          SELECT column_name, data_type, is_nullable, column_default
          FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = $1
          ORDER BY ordinal_position;
        `, [tbl]);
        if (res.rows.length === 0) {
          console.log(`No table named '${tbl}' found.`);
        } else {
          console.table(res.rows);
          console.log(`(${res.rows.length} columns in '${tbl}')\n`);
        }
      } catch (e) {
        console.error("Error:", e.message);
      }
      rl.prompt();
      return;
    }

    // Accumulate query until semicolon or execute immediately
    multilineBuffer += (multilineBuffer ? ' ' : '') + trimmed;

    if (trimmed.endsWith(';')) {
      const q = multilineBuffer;
      multilineBuffer = '';
      try {
        const start = Date.now();
        const res = await client.query(q);
        const elapsed = Date.now() - start;

        if (res.rows && res.rows.length > 0) {
          console.table(res.rows);
          console.log(`\n(${res.rows.length} row(s) in ${elapsed}ms)\n`);
        } else {
          console.log(`Command: ${res.command} | Affected: ${res.rowCount || 0} (${elapsed}ms)\n`);
        }
      } catch (e) {
        console.error("\n[Postgres Query Error]:", e.message, "\n");
      }
      rl.setPrompt('postgres=> ');
      rl.prompt();
    } else {
      rl.setPrompt('postgres-> ');
      rl.prompt();
    }
  });

  rl.on('close', async () => {
    console.log("\nClosing connection...");
    await client.end();
    process.exit(0);
  });
}

main();
