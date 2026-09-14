import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function verifyEvents() {
  console.log('================================================================');
  console.log('🔍 VERIFYING IMPORTED TECHNICAL EVENTS');
  console.log('================================================================\n');

  const client = new Client({ connectionString: CONN, ssl: { rejectUnauthorized: false } });
  await client.connect();

  // 1. Total events count
  const eventsRes = await client.query(`
    SELECT 
      id,
      title,
      category,
      event_type,
      venue,
      event_date::text AS event_date_str,
      start_time,
      end_time,
      status,
      submission_enabled,
      submission_deadline,
      voting_enabled,
      voting_start,
      voting_end,
      instructions
    FROM public.events
    ORDER BY 
      CASE 
        WHEN start_time IS NOT NULL THEN start_time 
        ELSE '23:59:59'::time 
      END ASC
  `);

  console.log(`1. Total Events in Database: ${eventsRes.rows.length} (Expected: 7)`);

  const events = eventsRes.rows;
  console.log('\n2. Event Details & Configuration Audit:\n');

  for (const ev of events) {
    const coordsRes = await client.query(`
      SELECT 
        coordinator_name,
        coordinator_type,
        is_primary,
        staff_id
      FROM public.event_coordinators
      WHERE event_id = $1
      ORDER BY coordinator_type ASC, is_primary DESC, coordinator_name ASC
    `, [ev.id]);

    const coords = coordsRes.rows;
    const faculty = coords.filter(c => c.coordinator_type === 'faculty');
    const students = coords.filter(c => c.coordinator_type === 'student');

    const facultyStr = faculty.length > 0 
      ? faculty.map(f => `${f.coordinator_name}${f.is_primary ? ' (Primary)' : ''}${f.staff_id ? ' [Linked Profile]' : ' [Unlinked]'}`).join(', ')
      : 'None (NULL)';

    const studentStr = students.length > 0
      ? students.map(s => `${s.coordinator_name}${s.staff_id ? ' [Linked Profile]' : ' [Unlinked]'}`).join(', ')
      : 'None (NULL)';

    const nullFields = [];
    if (ev.event_date === null) nullFields.push('event_date');
    if (ev.end_time === null) nullFields.push('end_time');
    if (ev.submission_deadline === null && ev.submission_enabled) nullFields.push('submission_deadline');
    if (faculty.length === 0) nullFields.push('faculty_coordinators');
    if (students.length === 0) nullFields.push('student_coordinators');

    console.log(`------------------------------------------------------------`);
    console.log(`📌 Title:               ${ev.title}`);
    console.log(`   ID:                  ${ev.id}`);
    console.log(`   Category:            ${ev.category}`);
    console.log(`   Status:              ${ev.status}`);
    console.log(`   Participation Type:  ${ev.event_type === 'team' ? 'Team (2–4 Members)' : 'Individual'}`);
    console.log(`   Date:                ${ev.event_date_str || 'NULL (Saturday - Date unassigned)'}`);
    console.log(`   Start Time:          ${ev.start_time}`);
    console.log(`   End Time:            ${ev.end_time || 'NULL'}`);
    console.log(`   Venue:               ${ev.venue}`);
    console.log(`   Faculty Coord(s):    ${facultyStr}`);
    console.log(`   Student Coord(s):    ${studentStr}`);
    console.log(`   Submission Enabled:  ${ev.submission_enabled ? `YES (Deadline: ${ev.submission_deadline || 'NULL/Configurable'})` : 'NO'}`);
    console.log(`   Voting Enabled:      ${ev.voting_enabled ? `YES (${ev.voting_start} to ${ev.voting_end})` : 'NO'}`);
    console.log(`   Fields Left NULL:    ${nullFields.length > 0 ? nullFields.join(', ') : 'None'}`);
  }

  console.log('\n------------------------------------------------------------');
  console.log('3. Zero-Fake Transactional Data Guarantee Check:');
  console.log('------------------------------------------------------------');

  const regCount = await client.query('SELECT count(*) FROM public.event_registrations');
  const teamCount = await client.query('SELECT count(*) FROM public.teams');
  const memberCount = await client.query('SELECT count(*) FROM public.team_members');
  const subCount = await client.query('SELECT count(*) FROM public.project_submissions');
  const voteCount = await client.query('SELECT count(*) FROM public.poll_votes');
  const attCount = await client.query('SELECT count(*) FROM public.event_attendance');

  console.log(`   Registrations: ${regCount.rows[0].count} (Expected: 0)`);
  console.log(`   Teams:         ${teamCount.rows[0].count} (Expected: 0)`);
  console.log(`   Team Members:  ${memberCount.rows[0].count} (Expected: 0)`);
  console.log(`   Submissions:   ${subCount.rows[0].count} (Expected: 0)`);
  console.log(`   Votes:         ${voteCount.rows[0].count} (Expected: 0)`);
  console.log(`   Attendance:    ${attCount.rows[0].count} (Expected: 0)`);

  const allZero = [regCount, teamCount, memberCount, subCount, voteCount, attCount].every(
    r => parseInt(r.rows[0].count, 10) === 0
  );

  if (allZero && events.length === 7) {
    console.log('\n🎉 ALL EVENT IMPORT AUDIT CHECKS PASSED 100%!');
  } else {
    console.error('\n❌ AUDIT MISMATCH DETECTED!');
  }

  await client.end();
}

verifyEvents().catch(console.error);
