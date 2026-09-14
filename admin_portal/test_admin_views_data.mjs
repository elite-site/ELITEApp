import supabaseAdmin from './src/services/supabase.js';

async function testAllAdminViews() {
  console.log('====================================================');
  console.log('   ADMIN PORTAL ALL VIEWS & DATA METHODS AUDIT');
  console.log('====================================================\n');

  let passed = 0;
  let failed = 0;

  function report(viewName, ok, details) {
    if (ok) {
      console.log(`[PASS] ${viewName}: ${details}`);
      passed++;
    } else {
      console.error(`[FAIL] ${viewName}: ${details}`);
      failed++;
    }
  }

  // 1. Dashboard View
  try {
    const metrics = await supabaseAdmin.getDashboardMetrics();
    report('1. DashboardView', typeof metrics === 'object', 
      `Students: ${metrics.students}, Staff: ${metrics.staff}, Events: ${metrics.events}, Registrations: ${metrics.registrations}, Polls: ${metrics.openPolls}`);
  } catch (e) {
    report('1. DashboardView', false, e.message);
  }

  // 2. Events View
  try {
    const events = await supabaseAdmin.getEvents();
    report('2. EventsView', Array.isArray(events) && events.length === 7, 
      `Loaded ${events.length} events with coordinator and registration counts`);
  } catch (e) {
    report('2. EventsView', false, e.message);
  }

  // 3. Students View
  try {
    const res = await supabaseAdmin.getStudents({ limit: 10, page: 0 });
    report('3. StudentsView', Array.isArray(res.students) && res.total > 0, 
      `Loaded ${res.students.length} students (Total across database: ${res.total})`);
  } catch (e) {
    report('3. StudentsView', false, e.message);
  }

  // 4. Faculty View (Staff)
  try {
    const staff = await supabaseAdmin.getStaff();
    report('4. FacultyView', Array.isArray(staff), 
      `Staff profiles loaded: ${staff.length}`);
  } catch (e) {
    report('4. FacultyView', false, e.message);
  }

  // 5. Attendance View
  try {
    const logs = await supabaseAdmin.getAttendanceLogs({ limit: 10 });
    report('5. AttendanceView', Array.isArray(logs), 
      `Recent attendance logs loaded: ${logs.length}`);
  } catch (e) {
    report('5. AttendanceView', false, e.message);
  }

  // 6. Polls View
  try {
    const polls = await supabaseAdmin.getPolls();
    report('6. PollsView', Array.isArray(polls) && polls.length > 0, 
      `Loaded ${polls.length} active polls`);
  } catch (e) {
    report('6. PollsView', false, e.message);
  }

  // 7. Broadcast View (Notifications)
  try {
    const notifs = await supabaseAdmin.getNotifications({ limit: 10 });
    report('7. BroadcastView', Array.isArray(notifs) && notifs.length > 0, 
      `Loaded ${notifs.length} notifications`);
  } catch (e) {
    report('7. BroadcastView', false, e.message);
  }

  // 8. Database View
  try {
    const tables = supabaseAdmin.getTableDefinitions();
    const counts = await supabaseAdmin.getTableCounts();
    report('8. DatabaseView', tables.length > 0 && typeof counts === 'object', 
      `Managed ${tables.length} tables with live row counts`);
  } catch (e) {
    report('8. DatabaseView', false, e.message);
  }

  // 9. Reports View
  try {
    const logs = await supabaseAdmin.getAttendanceLogs({ limit: 10 });
    const { students } = await supabaseAdmin.getStudents({ limit: 10 });
    const polls = await supabaseAdmin.getPolls();
    report('9. ReportsView', Array.isArray(logs) && Array.isArray(students) && Array.isArray(polls), 
      'All CSV export report data sources verified and active');
  } catch (e) {
    report('9. ReportsView', false, e.message);
  }

  console.log('\n====================================================');
  console.log(`SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('====================================================\n');

  if (failed > 0) process.exit(1);
}

testAllAdminViews().catch(console.error);
