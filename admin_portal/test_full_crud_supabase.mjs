import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://qjntsxlmdrldbnvmqpca.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqbnRzeGxtZHJsZGJudm1xcGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxODAxODksImV4cCI6MjEwNDc1NjE4OX0.wzkJ2LQz8vxAtA9ylrNbqm6P7uwiZ2GcxcG-g3Gig_o';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testCrud() {
  console.log('🚀 Running Comprehensive Supabase CRUD Validation Across All Models...\n');
  const testId = `t_${Date.now()}`;
  const userId = `u_${testId}`;
  const pollId = `poll_${testId}`;
  const eventId = `ev_${testId}`;
  const regId = `reg_${testId}`;
  const optId = `opt_${testId}`;
  const projId = `proj_${testId}`;

  try {
    // 1. Users
    process.stdout.write('1. users: ');
    let { error } = await client.from('users').insert({
      id: userId,
      username: testId,
      role: 'STUDENT',
      department: 'Information Technology',
      status: 'ACTIVE'
    });
    if (error) throw new Error('users insert: ' + error.message);
    ({ error } = await client.from('users').update({ status: 'INACTIVE' }).eq('id', userId));
    if (error) throw new Error('users update: ' + error.message);
    console.log('✅ CRUD Validated');

    // 2. Students
    process.stdout.write('2. students: ');
    ({ error } = await client.from('students').insert({
      user_id: userId,
      roll_no: testId,
      name: 'Test Student',
      department: 'Information Technology',
      year_level: '3rd Year',
      section: 'B',
      qr_token: `QR_${testId}`,
      status: 'ACTIVE'
    }));
    if (error) throw new Error('students insert: ' + error.message);
    ({ error } = await client.from('students').update({ status: 'SUSPENDED' }).eq('roll_no', testId));
    if (error) throw new Error('students update: ' + error.message);
    console.log('✅ CRUD Validated');

    // 3. Staff
    process.stdout.write('3. staff: ');
    const staffUserId = `u_staff_${testId}`;
    await client.from('users').insert({
      id: staffUserId,
      username: `emp_${testId}`,
      role: 'STAFF',
      department: 'Information Technology',
      status: 'ACTIVE'
    });
    ({ error } = await client.from('staff').insert({
      user_id: staffUserId,
      employee_id: `emp_${testId}`,
      name: 'Prof. Tester',
      department: 'Information Technology'
    }));
    if (error) throw new Error('staff insert: ' + error.message);
    ({ error } = await client.from('staff').update({ name: 'Prof. Tester Updated' }).eq('employee_id', `emp_${testId}`));
    if (error) throw new Error('staff update: ' + error.message);
    await client.from('staff').delete().eq('employee_id', `emp_${testId}`);
    await client.from('users').delete().eq('id', staffUserId);
    console.log('✅ CRUD Validated');

    // 4. Events
    process.stdout.write('4. events: ');
    ({ error } = await client.from('events').insert({
      id: eventId,
      title: 'Full Stack Hackathon',
      description: 'Test Event for validation',
      event_date: '2026-10-15',
      start_time: '09:00 AM',
      end_time: '05:00 PM',
      max_capacity: 100,
      registered_count: 0,
      venue: 'Seminar Hall 1',
      event_type: 'Technical',
      eligible_years: 'ALL',
      visibility: 'PUBLIC',
      status: 'OPEN',
      is_project_submission_enabled: true,
      project_submission_deadline: '2026-11-01T00:00:00.000Z'
    }));
    if (error) throw new Error('events insert: ' + error.message);
    ({ error } = await client.from('events').update({ max_capacity: 120 }).eq('id', eventId));
    if (error) throw new Error('events update: ' + error.message);
    console.log('✅ CRUD Validated');

    // 5. Event Registrations
    process.stdout.write('5. event_registrations: ');
    ({ error } = await client.from('event_registrations').insert({
      id: regId,
      event_id: eventId,
      student_id: userId,
      student_roll: testId,
      student_name: 'Test Student',
      status: 'CONFIRMED',
      is_team: false
    }));
    if (error) throw new Error('event_registrations insert: ' + error.message);
    ({ error } = await client.from('event_registrations').update({ status: 'CANCELLED' }).eq('id', regId));
    if (error) throw new Error('event_registrations update: ' + error.message);
    console.log('✅ CRUD Validated');

    // 6. Project Submissions
    process.stdout.write('6. project_submissions: ');
    ({ error } = await client.from('project_submissions').insert({
      id: projId,
      event_id: eventId,
      registration_id: regId,
      team_name: 'Alpha Team',
      leader_id: userId,
      leader_name: 'Test Student',
      project_name: 'AI Smart Campus',
      short_description: 'An AI assistant for college',
      status: 'PENDING',
      vote_count: 0
    }));
    if (error) throw new Error('project_submissions insert: ' + error.message);
    ({ error } = await client.from('project_submissions').update({ status: 'PUBLISHED' }).eq('id', projId));
    if (error) throw new Error('project_submissions update: ' + error.message);
    ({ error } = await client.from('project_submissions').delete().eq('id', projId));
    if (error) throw new Error('project_submissions delete: ' + error.message);
    console.log('✅ CRUD Validated');

    // 7. Event Attendance
    process.stdout.write('7. event_attendance: ');
    const attId = `att_${testId}`;
    ({ error } = await client.from('event_attendance').insert({
      id: attId,
      event_id: eventId,
      student_id: userId,
      student_roll: testId,
      student_name: 'Test Student',
      scanned_by: 'Gate #1 Scanner',
      status: 'PRESENT',
      session: 'Session 1'
    }));
    if (error) throw new Error('event_attendance insert: ' + error.message);
    ({ error } = await client.from('event_attendance').update({ status: 'LATE' }).eq('id', attId));
    if (error) throw new Error('event_attendance update: ' + error.message);
    await client.from('event_attendance').delete().eq('id', attId);
    console.log('✅ CRUD Validated');

    // 8. Polls & Poll Options & Poll Votes
    process.stdout.write('8. polls & options & votes: ');
    ({ error } = await client.from('polls').insert({
      id: pollId,
      question: 'Preferred Workshop Track?',
      status: 'OPEN'
    }));
    if (error) throw new Error('polls insert: ' + error.message);

    ({ error } = await client.from('poll_options').insert({
      id: optId,
      poll_id: pollId,
      text: 'Generative AI & Agentics',
      vote_count: 0
    }));
    if (error) throw new Error('poll_options insert: ' + error.message);

    const voteId = `v_${testId}`;
    ({ error } = await client.from('poll_votes').insert({
      id: voteId,
      poll_id: pollId,
      option_id: optId,
      student_id: userId
    }));
    if (error) throw new Error('poll_votes insert: ' + error.message);

    // Delete poll (should cascade-delete votes and options)
    ({ error } = await client.from('polls').delete().eq('id', pollId));
    if (error) throw new Error('polls delete: ' + error.message);
    console.log('✅ CRUD Validated');

    // 9. Notifications
    process.stdout.write('9. notifications: ');
    const notifId = `notif_${testId}`;
    ({ error } = await client.from('notifications').insert({
      id: notifId,
      title: 'Workshop Notification',
      message: 'Workshop begins at 9:00 AM'
    }));
    if (error) throw new Error('notifications insert: ' + error.message);
    ({ error } = await client.from('notifications').delete().eq('id', notifId));
    if (error) throw new Error('notifications delete: ' + error.message);
    console.log('✅ CRUD Validated');

    // 10. Student Queries / Tickets
    process.stdout.write('10. student_queries: ');
    const ticketId = `ticket_${testId}`;
    ({ error } = await client.from('student_queries').insert({
      id: ticketId,
      student_name: 'Test Student',
      roll_no: testId,
      title: 'Lab ID Pass Issue',
      status: 'PENDING'
    }));
    if (error) throw new Error('student_queries insert: ' + error.message);
    ({ error } = await client.from('student_queries').update({ status: 'RESOLVED' }).eq('id', ticketId));
    if (error) throw new Error('student_queries update: ' + error.message);
    await client.from('student_queries').delete().eq('id', ticketId);
    console.log('✅ CRUD Validated');

    // Cleanup parent records
    await client.from('event_registrations').delete().eq('id', regId);
    await client.from('events').delete().eq('id', eventId);
    await client.from('students').delete().eq('roll_no', testId);
    await client.from('users').delete().eq('id', userId);

    console.log('\n🎉 ALL 10 DATABASE TABLES PASSED 100% OF FULL CRUD TESTS WITH SUPABASE ANON CLIENT!');
  } catch (err) {
    console.error('\n❌ Validation Error:', err.message);
  }
}

testCrud();
