import xlsx from 'xlsx';
import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:[YOUR-PASSWORD]@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function main() {
  const client = new Client({ connectionString: CONN, ssl: { rejectUnauthorized: false } });
  await client.connect();
  console.log("Connected.");

  // Step 1: Clear students table
  await client.query("DELETE FROM students;");
  console.log("Cleared students table.");

  // Step 2: Read Excel
  const workbook = xlsx.readFile('C:\\Users\\phani\\StudioProjects\\elite_app\\Combined Student List.xlsx');
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const rows = xlsx.utils.sheet_to_json(sheet, { header: 1 });
  const dataRows = rows.slice(1).filter(r => r && r[1] && r[2]); // skip header, require name+rollno
  console.log(`Found ${dataRows.length} rows in Excel.`);

  const getYear = (roman) => {
    const map = { 'I': '1st Year', 'II': '2nd Year', 'III': '3rd Year', 'IV': '4th Year' };
    return map[roman?.toString().trim()] ?? (roman + ' Year');
  };

  // Step 3: Insert students — roll_no as password, no duplicates (use ON CONFLICT DO NOTHING)
  const seen = new Set();
  let inserted = 0;
  let skipped = 0;

  for (const row of dataRows) {
    const name = row[1]?.toString().trim();
    const rollNo = row[2]?.toString().trim().toUpperCase();
    const year = row[3]?.toString().trim();
    const section = row[4]?.toString().trim() || 'A';

    if (!name || !rollNo) { skipped++; continue; }
    if (seen.has(rollNo)) { console.log(`  DUPLICATE skipped: ${rollNo}`); skipped++; continue; }
    seen.add(rollNo);

    const userId = `u_${rollNo.toLowerCase()}`;
    const password = rollNo.toLowerCase(); // password = same as roll no (lowercase)
    const yearLevel = getYear(year);
    const qrToken = `ELITE_QR_${rollNo}`;

    await client.query(
      `INSERT INTO students (user_id, roll_no, name, department, year_level, section, qr_token, password_hash)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (roll_no) DO UPDATE SET name=$3, year_level=$5, section=$6, password_hash=$8`,
      [userId, rollNo, name, 'Information Technology', yearLevel, section, qrToken, password]
    );
    inserted++;
  }
  console.log(`Inserted/updated: ${inserted}, Skipped: ${skipped}`);

  // Step 4: Insert admin into users table
  await client.query("DELETE FROM users WHERE username = 'admin@123';");
  await client.query(
    `INSERT INTO users (id, username, password_hash, role, department, status, must_change_password)
     VALUES ('u_admin_001', 'admin@123', '123@admin', 'SUPER_ADMIN', 'Information Technology', 'ACTIVE', false)`,
  );
  console.log("Admin inserted into users table.");

  // Verify
  const stuCount = await client.query("SELECT COUNT(*) FROM students;");
  const adminRow = await client.query("SELECT id, username, role FROM users WHERE username = 'admin@123';");
  console.log(`\nStudents in DB: ${stuCount.rows[0].count}`);
  console.log("Admin row:", adminRow.rows[0]);

  await client.end();
  console.log("\nDone!");
}

main().catch(e => { console.error(e); process.exit(1); });
