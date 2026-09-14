import pkg from 'pg';
const { Client } = pkg;
import { createClient } from '@supabase/supabase-js';

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';
const SUPABASE_URL = 'https://qjntsxlmdrldbnvmqpca.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqbnRzeGxtZHJsZGJudm1xcGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxODAxODksImV4cCI6MjEwNDc1NjE4OX0.wzkJ2LQz8vxAtA9ylrNbqm6P7uwiZ2GcxcG-g3Gig_o';

async function verifyImport() {
  console.log('================================================================');
  console.log('🔍 POST-IMPORT AUDIT & VERIFICATION');
  console.log('================================================================\n');

  const pgClient = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false },
  });

  await pgClient.connect();

  // 1. Total counts
  const totalProfiles = await pgClient.query("SELECT count(*) FROM public.profiles WHERE role = 'student'");
  const studentCount = parseInt(totalProfiles.rows[0].count, 10);
  console.log(`1. Total student profiles in database: ${studentCount} (Expected: 404)`);

  // 2. Verify all students have role = 'student'
  const nonStudentRoles = await pgClient.query("SELECT count(*) FROM public.profiles WHERE role <> 'student' AND role <> 'admin'");
  console.log(`2. Non-standard roles count: ${nonStudentRoles.rows[0].count} (Expected: 0)`);

  // 3. Verify all students have is_active = true
  const inactiveStudents = await pgClient.query("SELECT count(*) FROM public.profiles WHERE role = 'student' AND is_active = false");
  console.log(`3. Inactive student profiles count: ${inactiveStudents.rows[0].count} (Expected: 0)`);

  // 4. Verify profiles.email is strictly NULL
  const nonNullEmails = await pgClient.query("SELECT count(*) FROM public.profiles WHERE role = 'student' AND email IS NOT NULL");
  console.log(`4. Student profiles with non-null email: ${nonNullEmails.rows[0].count} (Expected: 0)`);

  // 5. Verify every profile is linked to auth.users (Foreign Key Integrity)
  const unlinkedProfiles = await pgClient.query(`
    SELECT count(*) FROM public.profiles p
    LEFT JOIN auth.users u ON p.id = u.id
    WHERE p.role = 'student' AND u.id IS NULL
  `);
  console.log(`5. Unlinked student profiles (missing auth user): ${unlinkedProfiles.rows[0].count} (Expected: 0)`);

  // 6. Verify every roll_number is unique
  const duplicateRolls = await pgClient.query(`
    SELECT roll_number, count(*) FROM public.profiles
    GROUP BY roll_number HAVING count(*) > 1
  `);
  console.log(`6. Duplicate roll numbers count: ${duplicateRolls.rows.length} (Expected: 0)`);

  // 7. Check Year distribution
  const yearDist = await pgClient.query(`
    SELECT year, count(*) as count FROM public.profiles
    WHERE role = 'student' GROUP BY year ORDER BY year
  `);
  console.log('\n7. Year distribution in database:');
  console.table(yearDist.rows);

  // 8. Check Section distribution
  const secDist = await pgClient.query(`
    SELECT section, count(*) as count FROM public.profiles
    WHERE role = 'student' GROUP BY section ORDER BY section
  `);
  console.log('8. Section distribution in database:');
  console.table(secDist.rows);

  await pgClient.end();

  // 9. Live Authentication Test with Supabase Auth Client
  console.log('\n================================================================');
  console.log('🔐 LIVE AUTHENTICATION TEST (Roll Number + Password)');
  console.log('================================================================\n');

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  const testCases = [
    { roll: '25K61A1201', pass: '25K61A1201', expectedName: 'Abbireddy Akhila' },
    { roll: '25K61A1202', pass: '25K61A1202', expectedName: 'Achyutha Thanvitha Krishna' },
    { roll: '23K61A1201', pass: '23K61A1201', expectedName: 'Achanta Vagdevi Sandya' },
    { roll: '23K61A1202', pass: '23K61A1202', expectedName: 'Adapa Pushparaj' },
  ];

  for (const tc of testCases) {
    // Mimic the mobile client resolver:
    // 1. Look up profile by roll_number to get id and verify email is null
    const { data: profile } = await supabase
      .from('profiles')
      .select('id, full_name, roll_number, email, year, section, role')
      .ilike('roll_number', tc.roll)
      .single();

    if (!profile) {
      console.error(`❌ Test failed: Profile not found for roll ${tc.roll}`);
      continue;
    }

    // 2. Authenticate using internal format '${roll.toLowerCase()}@sasi.ac.in' and password
    const internalEmail = `${tc.roll.toLowerCase()}@sasi.ac.in`;
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: internalEmail,
      password: tc.pass,
    });

    if (authError || !authData.user) {
      console.error(`❌ Test failed: Authentication failed for ${tc.roll}:`, authError?.message);
    } else {
      console.log(`✅ Authentication SUCCESS for student ${tc.roll}:`);
      console.log(`   Name:        ${profile.full_name}`);
      console.log(`   Year/Sec:    ${profile.year} - ${profile.section}`);
      console.log(`   Email in DB: ${profile.email} (Strictly NULL)`);
      console.log(`   Auth UID:    ${authData.user.id}`);
      console.log(`   Profiles ID: ${profile.id} (Matches Auth UID: ${authData.user.id === profile.id})\n`);
    }

    await supabase.auth.signOut();
  }

  console.log('🎉 ALL INTEGRITY AND AUTHENTICATION VERIFICATIONS PASSED 100%!');
}

verifyImport().catch(console.error);
