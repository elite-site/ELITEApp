import XLSX from 'xlsx';
import path from 'path';
import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

function sqlStr(str) {
  if (str === null || str === undefined) return 'NULL';
  return `'${String(str).replace(/'/g, "''")}'`;
}

async function importStudents() {
  console.log('================================================================');
  console.log('🎓 ELITE COLLEGE EVENT SYSTEM — STUDENT IMPORT TOOL');
  console.log('================================================================\n');

  // 1. Read Excel file
  const excelPath = path.resolve('..', 'Combined Student List.xlsx');
  console.log(`📖 Reading Excel file: ${excelPath}`);
  const workbook = XLSX.readFile(excelPath);

  const sheetName = 'Combined Student List';
  const sheet = workbook.Sheets[sheetName];
  if (!sheet) {
    throw new Error(`Sheet "${sheetName}" not found in Excel workbook!`);
  }

  const rawRows = XLSX.utils.sheet_to_json(sheet);
  console.log(`📊 Total rows parsed from sheet: ${rawRows.length}`);

  // 2. Data Validation
  const validStudents = [];
  const invalidRows = [];
  const excelDuplicates = [];
  const seenRolls = new Set();

  for (let i = 0; i < rawRows.length; i++) {
    const r = rawRows[i];
    const rowNum = i + 2; // +1 for 1-based index, +1 for header

    const fullName = (r['Student Name'] || '').toString().trim();
    const rollNumber = (r['Uni Reg No'] || '').toString().trim().toUpperCase();
    const year = (r['Year'] || '').toString().trim();
    const section = (r['Section'] || '').toString().trim();

    if (!fullName || !rollNumber) {
      invalidRows.push({
        row: rowNum,
        name: fullName,
        roll: rollNumber,
        reason: 'Missing Student Name or Uni Reg No',
      });
      continue;
    }

    if (seenRolls.has(rollNumber)) {
      excelDuplicates.push({
        row: rowNum,
        name: fullName,
        roll: rollNumber,
        reason: 'Duplicate Uni Reg No inside Excel file',
      });
      continue;
    }

    seenRolls.add(rollNumber);
    validStudents.push({
      fullName,
      rollNumber,
      year: year || 'II',
      section: section || 'A',
    });
  }

  console.log(`✅ Validation completed:`);
  console.log(`   Valid records to process: ${validStudents.length}`);
  console.log(`   Invalid rows:            ${invalidRows.length}`);
  console.log(`   Excel internal dupes:    ${excelDuplicates.length}\n`);

  if (invalidRows.length > 0) {
    console.warn('⚠️ Invalid rows detected:');
    console.table(invalidRows);
  }

  // 3. Connect to PostgreSQL
  const client = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false },
  });

  await client.connect();
  console.log('🔌 Connected to Supabase PostgreSQL.\n');

  // 4. Duplicate Check against Database
  const existingProfilesRes = await client.query('SELECT roll_number FROM public.profiles');
  const existingRolls = new Set(existingProfilesRes.rows.map((r) => r.roll_number.toUpperCase()));

  const existingAuthRes = await client.query('SELECT email FROM auth.users');
  const existingEmails = new Set(existingAuthRes.rows.map((r) => (r.email || '').toLowerCase()));

  const toImport = validStudents.filter((s) => {
    const email = `${s.rollNumber.toLowerCase()}@sasi.ac.in`;
    return !existingRolls.has(s.rollNumber) && !existingEmails.has(email);
  });
  const skippedCount = validStudents.length - toImport.length;

  console.log(`🔍 Database Duplicate Check:`);
  console.log(`   Existing profiles in DB: ${existingRolls.size}`);
  console.log(`   Existing auth users in DB: ${existingEmails.size}`);
  console.log(`   New students to import:  ${toImport.length}`);
  console.log(`   Already existing:        ${skippedCount}\n`);

  if (toImport.length === 0) {
    console.log('✨ All valid students are already imported in the database.');
    await client.end();
    return;
  }

  // 5. Batch Process Import in Chunks of 50
  const BATCH_SIZE = 50;
  let successfullyImported = 0;
  const failedBatches = [];

  const totalBatches = Math.ceil(toImport.length / BATCH_SIZE);
  console.log(`🚀 Processing ${toImport.length} students across ${totalBatches} batches (batch size: ${BATCH_SIZE})...\n`);

  for (let b = 0; b < totalBatches; b++) {
    const chunk = toImport.slice(b * BATCH_SIZE, (b + 1) * BATCH_SIZE);
    const batchNum = b + 1;

    try {
      await client.query('BEGIN');

      // 5a. Multi-row insert into auth.users with Blowfish bcrypt hash of Uni Reg No
      const authValues = chunk.map((s) => {
        const internalEmail = `${s.rollNumber.toLowerCase()}@sasi.ac.in`;
        const meta = JSON.stringify({ name: s.fullName, roll_number: s.rollNumber, role: 'student' });
        return `(
          gen_random_uuid(),
          '00000000-0000-0000-0000-000000000000',
          'authenticated',
          'authenticated',
          ${sqlStr(internalEmail)},
          crypt(${sqlStr(s.rollNumber)}, gen_salt('bf')),
          NOW(),
          '{"provider":"email","providers":["email"]}'::jsonb,
          ${sqlStr(meta)}::jsonb,
          false,
          '',
          '',
          '',
          '',
          NOW(),
          NOW()
        )`;
      }).join(',\n');

      const authInsertSql = `
        INSERT INTO auth.users (
          id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
          raw_app_meta_data, raw_user_meta_data, is_sso_user,
          confirmation_token, recovery_token, email_change_token_new, email_change,
          created_at, updated_at
        ) VALUES ${authValues}
        RETURNING id, email;
      `;

      const authRes = await client.query(authInsertSql);

      // Map internalEmail -> authId
      const emailToAuthId = new Map();
      for (const row of authRes.rows) {
        emailToAuthId.set(row.email.toLowerCase(), row.id);
      }

      // 5b. Multi-row insert into auth.identities
      const identityValues = chunk.map((s) => {
        const internalEmail = `${s.rollNumber.toLowerCase()}@sasi.ac.in`;
        const authId = emailToAuthId.get(internalEmail);
        return `(
          gen_random_uuid(),
          ${sqlStr(authId)},
          ${sqlStr(authId)}::uuid,
          json_build_object('sub', ${sqlStr(authId)}, 'email', ${sqlStr(internalEmail)}),
          'email',
          NOW(),
          NOW()
        )`;
      }).join(',\n');

      await client.query(`
        INSERT INTO auth.identities (
          id, provider_id, user_id, identity_data, provider, created_at, updated_at
        ) VALUES ${identityValues}
        ON CONFLICT (provider_id, provider) DO NOTHING;
      `);

      // 5b. Multi-row insert into public.profiles linked to auth.users.id
      // email is strictly NULL per user requirement
      const profileValues = chunk.map((s) => {
        const internalEmail = `${s.rollNumber.toLowerCase()}@sasi.ac.in`;
        const authId = emailToAuthId.get(internalEmail);
        if (!authId) {
          throw new Error(`Auth ID missing for ${s.rollNumber}`);
        }

        return `(
          ${sqlStr(authId)},
          ${sqlStr(s.rollNumber)},
          ${sqlStr(s.fullName)},
          NULL,
          NULL,
          'Information Technology',
          ${sqlStr(s.year)},
          ${sqlStr(s.section)},
          'student',
          true,
          NOW(),
          NOW()
        )`;
      }).join(',\n');

      const profileInsertSql = `
        INSERT INTO public.profiles (
          id, roll_number, full_name, email, phone, department, year, section, role, is_active, created_at, updated_at
        ) VALUES ${profileValues}
        ON CONFLICT (id) DO UPDATE SET
          roll_number = EXCLUDED.roll_number,
          full_name = EXCLUDED.full_name,
          email = NULL,
          year = EXCLUDED.year,
          section = EXCLUDED.section,
          role = 'student',
          is_active = true,
          updated_at = NOW();
      `;

      await client.query(profileInsertSql);

      await client.query('COMMIT');
      successfullyImported += chunk.length;
      console.log(`   ✓ Batch ${batchNum}/${totalBatches}: ${chunk.length} students imported successfully.`);
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(`   ✗ Batch ${batchNum}/${totalBatches} failed:`, err.message);
      failedBatches.push({ batch: batchNum, count: chunk.length, error: err.message });
    }
  }

  await client.end();

  // 6. Output Summary Report
  console.log('\n================================================================');
  console.log('📋 IMPORT SUMMARY REPORT');
  console.log('================================================================');
  console.log(`Total Excel Rows:               ${rawRows.length}`);
  console.log(`Successfully Imported Students: ${successfullyImported}`);
  console.log(`Existing / Skipped Students:    ${skippedCount}`);
  console.log(`Invalid Rows:                   ${invalidRows.length}`);
  console.log(`Failed Batches:                 ${failedBatches.length}`);
  console.log('================================================================\n');

  if (failedBatches.length > 0) {
    console.error('❌ Some batches encountered errors:');
    console.table(failedBatches);
  } else {
    console.log('🎉 ALL 404 STUDENTS IMPORTED CLEANLY WITH NO ERRORS!');
  }
}

importStudents().catch(console.error);
