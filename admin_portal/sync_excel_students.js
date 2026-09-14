import fs from 'fs';
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://qjntsxlmdrldbnvmqpca.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqbnRzeGxtZHJsZGJudm1xcGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxODAxODksImV4cCI6MjEwNDc1NjE4OX0.wzkJ2LQz8vxAtA9ylrNbqm6P7uwiZ2GcxcG-g3Gig_o';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function main() {
  console.log("=== STARTING SUPABASE STUDENT & STAFF/ADMIN SYNC ===");

  // 1. Load 404 students from JSON
  const students = JSON.parse(fs.readFileSync('students_from_excel.json', 'utf8'));
  console.log(`Loaded ${students.length} students from Excel JSON.`);

  const excelRollNos = new Set(students.map(s => s.roll_no));

  // 2. Fetch all current students in DB
  const { data: dbStudents, error: fetchErr } = await supabase
    .from('students')
    .select('roll_no, user_id');
  if (fetchErr) throw fetchErr;

  console.log(`Current students in DB: ${dbStudents.length}`);

  // 3. Identify obsolete students to remove
  const obsoleteStudents = dbStudents.filter(s => !excelRollNos.has(s.roll_no));
  console.log(`Found ${obsoleteStudents.length} obsolete students to remove.`);

  for (const s of obsoleteStudents) {
    console.log(`Deleting obsolete student: ${s.roll_no} (${s.user_id})`);
    const { error: delStudErr } = await supabase
      .from('students')
      .delete()
      .eq('roll_no', s.roll_no);
    if (delStudErr) console.error(`Error deleting student ${s.roll_no}:`, delStudErr);

    const { error: delUserErr } = await supabase
      .from('users')
      .delete()
      .eq('id', s.user_id);
    if (delUserErr) console.error(`Error deleting user ${s.user_id}:`, delUserErr);
  }

  // 4. Update Admin and Staff accounts to @sasi.ac.in
  console.log("Updating Admin and Staff accounts with official @sasi.ac.in emails...");

  const adminUser = {
    id: 'u_admin',
    username: 'admin',
    email: 'admin@sasi.ac.in',
    password_hash: 'MANAGED_AUTH',
    role: 'SUPER_ADMIN',
    department: 'Information Technology',
    status: 'ACTIVE',
    must_change_password: false,
    updated_at: new Date().toISOString()
  };

  const staffUser1 = {
    id: 'u_staff01',
    username: 'hod_it',
    email: 'hod_it@sasi.ac.in',
    password_hash: 'MANAGED_AUTH',
    role: 'STAFF',
    department: 'Information Technology',
    status: 'ACTIVE',
    must_change_password: false,
    updated_at: new Date().toISOString()
  };

  const staffUser2 = {
    id: 'u_staff02',
    username: 'staff01',
    email: 'staff@sasi.ac.in',
    password_hash: 'MANAGED_AUTH',
    role: 'STAFF',
    department: 'Information Technology',
    status: 'ACTIVE',
    must_change_password: false,
    updated_at: new Date().toISOString()
  };

  for (const u of [adminUser, staffUser1, staffUser2]) {
    const { error } = await supabase.from('users').upsert(u);
    if (error) console.error(`Error upserting user ${u.id}:`, error);
    else console.log(`Upserted user: ${u.id} (${u.email}) [${u.role}]`);
  }

  const staffRecord1 = {
    user_id: 'u_staff01',
    employee_id: 'EMP_IT_01',
    name: 'Dr. AVN Chandra Sekhar',
    designation: 'Head of Department (HoD)',
    department: 'Information Technology',
    email: 'hod_it@sasi.ac.in',
    phone: '+91 98480 12345',
    cabin: 'HoD Chamber, IT Dept'
  };

  const staffRecord2 = {
    user_id: 'u_staff02',
    employee_id: 'EMP_IT_02',
    name: 'Dr. Ramesh Kumar',
    designation: 'Assistant Professor & Coordinator',
    department: 'Information Technology',
    email: 'staff@sasi.ac.in',
    phone: '+91 94401 56789',
    cabin: 'Cabin 4, Staff Room A'
  };

  for (const st of [staffRecord1, staffRecord2]) {
    const { error } = await supabase.from('staff').upsert(st);
    if (error) console.error(`Error upserting staff ${st.user_id}:`, error);
    else console.log(`Upserted staff: ${st.user_id} (${st.email})`);
  }

  // 5. Batch Upsert 404 Students into `users` table
  console.log("Upserting 404 students into `users` table...");
  const userRows = students.map(s => ({
    id: s.user_id,
    username: s.roll_no,
    email: s.email,
    password_hash: 'MANAGED_AUTH',
    role: 'STUDENT',
    department: 'Information Technology',
    status: 'ACTIVE',
    must_change_password: false,
    updated_at: new Date().toISOString()
  }));

  const BATCH_SIZE = 50;
  for (let i = 0; i < userRows.length; i += BATCH_SIZE) {
    const batch = userRows.slice(i, i + BATCH_SIZE);
    const { error } = await supabase.from('users').upsert(batch, { onConflict: 'id' });
    if (error) {
      console.error(`Error upserting users batch ${i} to ${i + batch.length}:`, error);
      throw error;
    }
    console.log(`Upserted users batch ${i + 1} - ${Math.min(i + BATCH_SIZE, userRows.length)} / ${userRows.length}`);
  }

  // 6. Batch Upsert 404 Students into `students` table
  console.log("Upserting 404 students into `students` table...");
  const studentRows = students.map(s => ({
    user_id: s.user_id,
    roll_no: s.roll_no,
    name: s.name,
    email: s.email,
    department: s.department,
    year_level: s.year_level,
    section: s.section,
    academic_year_id: s.academic_year_id,
    qr_token: s.qr_token,
    status: s.status,
    updated_at: new Date().toISOString()
  }));

  for (let i = 0; i < studentRows.length; i += BATCH_SIZE) {
    const batch = studentRows.slice(i, i + BATCH_SIZE);
    const { error } = await supabase.from('students').upsert(batch, { onConflict: 'roll_no' });
    if (error) {
      console.error(`Error upserting students batch ${i} to ${i + batch.length}:`, error);
      throw error;
    }
    console.log(`Upserted students batch ${i + 1} - ${Math.min(i + BATCH_SIZE, studentRows.length)} / ${studentRows.length}`);
  }

  // 7. Verify Final Counts
  console.log("\n=== VERIFYING FINAL DATABASE COUNTS ===");
  const { count: studentCount } = await supabase.from('students').select('*', { count: 'exact', head: true });
  const { count: userCount } = await supabase.from('users').select('*', { count: 'exact', head: true });
  const { count: staffCount } = await supabase.from('staff').select('*', { count: 'exact', head: true });
  const { count: studentUserCount } = await supabase.from('users').select('*', { count: 'exact', head: true }).eq('role', 'STUDENT');

  console.log(`Final Students count: ${studentCount} (Expected: 404)`);
  console.log(`Final Student Users count: ${studentUserCount} (Expected: 404)`);
  console.log(`Final Total Users count: ${userCount} (Expected: 407 [404 + 1 Admin + 2 Staff])`);
  console.log(`Final Staff count: ${staffCount} (Expected: 2)`);

  if (studentCount === 404 && studentUserCount === 404 && userCount === 407) {
    console.log("\nSUCCESS: All student, staff, and admin records match exactly!");
  } else {
    console.warn("\nWARNING: Counts do not match expected numbers exactly. Please verify.");
  }
}

main().catch(err => {
  console.error("Migration script failed:", err);
  process.exit(1);
});
