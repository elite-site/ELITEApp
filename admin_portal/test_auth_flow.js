import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function testAuth() {
  const client = new Client({ connectionString: CONN, ssl: { rejectUnauthorized: false } });
  await client.connect();

  console.log("=== TESTING PRODUCTION AUTH & ROLE RESOLUTION ===");

  // Test 1: Student credentials
  const testStudentRoll = '24K61A1259';
  const testStudentPass = '24k61a1259';

  const stuAuth = await client.query(
    `SELECT s.user_id, s.roll_no, p.name, p.role, p.department
     FROM students s
     JOIN profiles p ON p.id = s.user_id
     WHERE UPPER(s.roll_no) = $1 AND s.password_hash = $2;`,
    [testStudentRoll.toUpperCase(), testStudentPass.toLowerCase()]
  );

  console.log("\n[Test 1] Student Auth Result:", stuAuth.rows[0]);
  if (stuAuth.rows[0]?.role === 'student') {
    console.log(">>> SUCCESS: Authenticated as Student with server-side role 'student'");
  } else {
    console.error(">>> FAILED: Student auth");
  }

  // Test 2: Staff credentials
  const testStaffUser = 'hod_it';
  const testStaffPass = 'hod_it';

  const staffAuth = await client.query(
    `SELECT st.user_id, st.employee_id, p.name, p.role, p.department
     FROM staff st
     JOIN profiles p ON p.id = st.user_id
     WHERE st.username = $1 AND st.password_hash = $2;`,
    [testStaffUser, testStaffPass]
  );

  console.log("\n[Test 2] Staff Auth Result:", staffAuth.rows[0]);
  if (staffAuth.rows[0]?.role === 'staff') {
    console.log(">>> SUCCESS: Authenticated as Staff with server-side role 'staff'");
  } else {
    console.error(">>> FAILED: Staff auth");
  }

  // Test 3: Admin credentials
  const testAdminUser = 'admin';
  const testAdminPass = 'admin123';

  const adminAuth = await client.query(
    `SELECT u.id, u.username, p.name, p.role, p.department
     FROM users u
     JOIN profiles p ON p.id = u.id
     WHERE u.username = $1 AND u.password_hash = $2 AND u.role IN ('SUPER_ADMIN', 'ADMIN');`,
    [testAdminUser, testAdminPass]
  );

  console.log("\n[Test 3] Admin Auth Result:", adminAuth.rows[0]);
  if (adminAuth.rows[0]?.role === 'admin') {
    console.log(">>> SUCCESS: Authenticated as Admin with server-side role 'admin'");
  } else {
    console.error(">>> FAILED: Admin auth");
  }

  await client.end();
}

testAuth().catch(console.error);
