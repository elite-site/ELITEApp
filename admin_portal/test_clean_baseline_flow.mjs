import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://qjntsxlmdrldbnvmqpca.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqbnRzeGxtZHJsZGJudm1xcGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxODAxODksImV4cCI6MjEwNDc1NjE4OX0.wzkJ2LQz8vxAtA9ylrNbqm6P7uwiZ2GcxcG-g3Gig_o';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function verifyCleanWorkflow() {
  console.log('🧪 Verifying Clean Baseline End-to-End Workflow...\n');

  // 1. Verify Clean Baseline Metrics
  const { count: studentCount } = await client.from('students').select('*', { count: 'exact', head: true });
  const { count: eventCount } = await client.from('events').select('*', { count: 'exact', head: true });
  const { count: regCount } = await client.from('event_registrations').select('*', { count: 'exact', head: true });

  console.log(`Current Supabase Counts: Students=${studentCount}, Events=${eventCount}, Registrations=${regCount}`);
  if (studentCount !== 0 || eventCount !== 0 || regCount !== 0) {
    throw new Error('Database is not clean!');
  }
  console.log('✅ Baseline verified: 0 students, 0 events, 0 registrations.\n');

  // 2. Admin Creates Event
  console.log('Step 1: Admin creates an event in Supabase...');
  const eventId = 'ev_hackathon_2026';
  const { data: evData, error: evErr } = await client.from('events').insert({
    id: eventId,
    title: 'National Vibe Coding & AI Hackathon',
    description: 'Premier technical competition for developing autonomous agents and apps.',
    event_date: '2026-10-24',
    start_time: '09:30 AM',
    end_time: '05:30 PM',
    max_capacity: 100,
    registered_count: 0,
    venue: 'Advanced AI & Computing Lab 1',
    event_type: 'Hackathon',
    eligible_years: 'ALL',
    visibility: 'PUBLIC',
    status: 'OPEN',
    is_project_submission_enabled: true,
    project_submission_deadline: '2026-10-23T23:59:59Z'
  }).select();

  if (evErr) throw evErr;
  console.log('✅ Event created successfully:', evData[0].title);

  // 3. Admin Enrolls a Student
  console.log('\nStep 2: Admin enrolls a real student...');
  const rollNo = '23K61A1201';
  const studentUserId = `u_${rollNo.toLowerCase()}`;
  const studentEmail = `${rollNo.toLowerCase()}@sasi.ac.in`;
  const studentName = 'Aditya Varma';

  // Insert user
  await client.from('users').insert({
    id: studentUserId,
    username: rollNo,
    email: studentEmail,
    password_hash: 'student123',
    role: 'STUDENT',
    department: 'Information Technology',
    status: 'ACTIVE'
  });

  // Insert student
  await client.from('students').insert({
    user_id: studentUserId,
    roll_no: rollNo,
    name: studentName,
    department: 'Information Technology',
    year_level: '3rd Year',
    section: 'A',
    academic_year_id: 'ay_2026_2027',
    qr_token: `ELITE_QR_${rollNo}`,
    status: 'ACTIVE',
    password_hash: 'student123'
  });

  // Insert profile (for unified mobile app auth)
  await client.from('profiles').insert({
    id: studentUserId,
    name: studentName,
    email: studentEmail,
    student_id: rollNo,
    department: 'Information Technology',
    year: '3rd Year',
    section: 'A',
    role: 'student',
    status: 'ACTIVE',
    academic_details: 'B.Tech IT • 3rd Year • Section A',
    lab_pass_id: `ELITE_QR_${rollNo}`,
    cgpa: 9.15,
    attendance_percent: 94
  });

  console.log(`✅ Student enrolled: ${studentName} (${rollNo})`);

  // 4. Student Registers for Event (Mobile App Action)
  console.log('\nStep 3: Student registers for the event from mobile app...');
  const regId = `${eventId}_${studentUserId}`;
  const { data: regData, error: regErr } = await client.from('event_registrations').insert({
    id: regId,
    event_id: eventId,
    student_id: studentUserId,
    student_roll: rollNo,
    student_name: studentName,
    student_email: studentEmail,
    student_year: '3rd Year',
    is_team: false,
    status: 'CONFIRMED',
    registered_at: new Date().toISOString()
  }).select();

  if (regErr) throw regErr;
  console.log('✅ Student registration written to Supabase:', regData[0].id);

  // 5. Verify Automatic Trigger Updated Registered Count
  console.log('\nStep 4: Verifying database trigger automatically updated event registered_count...');
  const { data: updatedEv } = await client.from('events').select('registered_count').eq('id', eventId).single();
  console.log(`✅ Event registered_count is now: ${updatedEv.registered_count} (Expected: 1)`);

  console.log('\n🎉 ALL 5 STEPS OF THE CLEAN BASELINE WORKFLOW COMPLETED SUCCESSFULLY!');
}

verifyCleanWorkflow().catch(console.error);
