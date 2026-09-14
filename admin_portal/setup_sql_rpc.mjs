import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function setupRpc() {
  const client = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false }
  });

  await client.connect();
  console.log("Connected to Supabase PostgreSQL.");

  await client.query(`
    CREATE OR REPLACE FUNCTION public.execute_sql_query(query_text text)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
      result jsonb;
    BEGIN
      EXECUTE 'SELECT jsonb_agg(t) FROM (' || query_text || ') t' INTO result;
      RETURN COALESCE(result, '[]'::jsonb);
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('error', SQLERRM);
    END;
    $$;

    GRANT EXECUTE ON FUNCTION public.execute_sql_query(text) TO public;
  `);

  console.log("execute_sql_query RPC created successfully.");

  // Test RPC execution
  const testRes = await client.query(`SELECT public.execute_sql_query('SELECT count(*) as total_students FROM public.students') as res;`);
  console.log("RPC Test result:", testRes.rows[0].res);

  await client.end();
}

setupRpc().catch(console.error);
