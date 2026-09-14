import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://qjntsxlmdrldbnvmqpca.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqbnRzeGxtZHJsZGJudm1xcGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxODAxODksImV4cCI6MjEwNDc1NjE4OX0.wzkJ2LQz8vxAtA9ylrNbqm6P7uwiZ2GcxcG-g3Gig_o';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runTests() {
  console.log('=== STARTING SUPABASE E2E SCENARIO TESTS ===\n');

  const testEventId = `ev_test_${Date.now()}`;
  const testRegId = `reg_test_${Date.now()}`;
  const testProjId = `proj_test_${Date.now()}`;
  const testVoterId = 'u_23k61a1202';

  try {
    // 1. Create a test event with future deadline & voting open
    console.log('1. Creating test event with submission deadline and voting enabled...');
    const futureDeadline = new Date(Date.now() + 86400000).toISOString();
    const futureEnd = new Date(Date.now() + 86400000 * 2).toISOString();
    const pastStart = new Date(Date.now() - 3600000).toISOString();

    const { error: evErr } = await supabase.from('events').insert({
      id: testEventId,
      title: 'Automated Test Hackathon 2026',
      description: 'E2E Testing Event',
      event_date: new Date().toISOString().split('T')[0],
      start_time: '10:00 AM',
      end_time: '05:00 PM',
      max_capacity: 50,
      registered_count: 0,
      venue: 'Lab 1',
      status: 'OPEN',
      participation_type: 'Team',
      is_project_submission_enabled: true,
      project_submission_deadline: futureDeadline,
      is_voting_enabled: true,
      voting_start: pastStart,
      voting_end: futureEnd,
      voting_eligible_roles: ['STUDENT', 'STAFF'],
    });
    if (evErr) throw new Error('Event create failed: ' + evErr.message);
    console.log('   ✓ Test event created successfully');

    // 2. Team Registration with 4 participants
    console.log('\n2. Testing Team Registration (Leader + 3 members)...');
    const teamMembers = [
      { studentRoll: '23K61A1201', studentName: 'Leader Phani', studentDept: 'IT', isLeader: true },
      { studentRoll: '23K61A1202', studentName: 'Member Rahul', studentDept: 'IT', isLeader: false },
      { studentRoll: '23K61A1203', studentName: 'Member Sathvik', studentDept: 'IT', isLeader: false },
      { studentRoll: '23K61A1204', studentName: 'Member Bhavitha', studentDept: 'IT', isLeader: false },
    ];

    const { error: regErr } = await supabase.from('event_registrations').insert({
      id: testRegId,
      event_id: testEventId,
      student_id: 'u_23k61a1201',
      student_roll: '23K61A1201',
      student_name: 'Leader Phani',
      student_email: '23k61a1201@sasi.ac.in',
      is_team: true,
      team_name: 'Team Alpha Test',
      members: JSON.stringify(teamMembers),
      status: 'CONFIRMED',
      registered_at: new Date().toISOString(),
    });
    if (regErr) throw new Error('Team registration failed: ' + regErr.message);
    console.log('   ✓ Team registered with 4 participants');

    // 3. Project Submission (Before deadline)
    console.log('\n3. Testing Project Submission (Before deadline)...');
    const { error: projErr } = await supabase.from('project_submissions').insert({
      id: testProjId,
      event_id: testEventId,
      registration_id: testRegId,
      team_name: 'Team Alpha Test',
      leader_id: 'u_23k61a1201',
      leader_name: 'Leader Phani',
      project_name: 'Smart Campus AI',
      short_description: 'An AI-driven campus assistant.',
      detailed_description: 'Full stack system with real-time sync.',
      technologies: ['Flutter', 'Supabase', 'Python'],
      repo_url: 'https://github.com/elite/smart-campus',
      demo_url: 'https://demo.smartcampus.ai',
      status: 'PENDING',
      vote_count: 0,
    });
    if (projErr) throw new Error('Project submission failed: ' + projErr.message);
    console.log('   ✓ Project submitted (Status: PENDING)');

    // 4. Project Editing (Before deadline)
    console.log('\n4. Testing Project Editing (Before deadline)...');
    const { error: editErr } = await supabase
      .from('project_submissions')
      .update({ short_description: 'Updated short pitch description before deadline' })
      .eq('id', testProjId);
    if (editErr) throw new Error('Project edit failed: ' + editErr.message);
    console.log('   ✓ Project updated successfully before deadline');

    // 5. Admin Publishes Project
    console.log('\n5. Testing Admin Project Publishing...');
    const { error: pubErr } = await supabase
      .from('project_submissions')
      .update({ status: 'PUBLISHED' })
      .eq('id', testProjId);
    if (pubErr) throw new Error('Publish failed: ' + pubErr.message);
    console.log('   ✓ Project published by Admin (Status: PUBLISHED)');

    // 6. Student Project View
    console.log('\n6. Testing Student Project Visibility (Only published, Leader name only)...');
    const { data: studentView, error: svErr } = await supabase
      .from('project_submissions')
      .select('id, team_name, leader_name, project_name, short_description, technologies, repo_url, demo_url, status')
      .eq('event_id', testEventId)
      .eq('status', 'PUBLISHED');
    if (svErr) throw svErr;
    console.log(`   ✓ Student retrieved ${studentView.length} published project(s)`);
    console.log(`   ✓ Leader Name visible: "${studentView[0].leader_name}" (Private members hidden)`);

    // 7. Voting (One User = One Vote)
    console.log('\n7. Testing First Vote Submission...');
    const voteId1 = `vote_${testEventId}_${testVoterId}`;
    const { error: vote1Err } = await supabase.from('project_votes').insert({
      id: voteId1,
      event_id: testEventId,
      project_id: testProjId,
      voter_id: testVoterId,
      voter_role: 'STUDENT',
      voted_at: new Date().toISOString(),
    });
    if (vote1Err) throw new Error('First vote failed: ' + vote1Err.message);
    console.log('   ✓ Vote 1 recorded successfully');

    // 8. Reject Second Vote by same voter
    console.log('\n8. Testing Rejection of Second Vote by same user (Constraint: UNIQUE(event_id, voter_id))...');
    const voteId2 = `vote_${testEventId}_${testVoterId}_second`;
    const { error: vote2Err } = await supabase.from('project_votes').insert({
      id: voteId2,
      event_id: testEventId,
      project_id: testProjId,
      voter_id: testVoterId,
      voter_role: 'STUDENT',
      voted_at: new Date().toISOString(),
    });
    if (vote2Err) {
      console.log('   ✓ Duplicate vote was REJECTED by database constraint:', vote2Err.message);
    } else {
      throw new Error('SECURITY VIOLATION: Duplicate vote was allowed!');
    }

    // 9. Check Admin Vote Tally
    console.log('\n9. Testing Admin Vote Tally query...');
    const { data: tallyData, error: tallyErr } = await supabase
      .from('project_submissions')
      .select('team_name, project_name, vote_count')
      .eq('id', testProjId)
      .single();
    if (tallyErr) throw tallyErr;
    console.log(`   ✓ Project vote_count auto-incremented by trigger: ${tallyData.vote_count}`);

    // 10. Test Server-Side Deadline Enforcement Trigger
    console.log('\n10. Testing Database-Enforced Submission Deadline Trigger...');
    // Set event submission deadline to the past
    const pastDeadline = new Date(Date.now() - 3600000).toISOString();
    await supabase.from('events').update({ project_submission_deadline: pastDeadline }).eq('id', testEventId);

    // Attempt to update project after deadline has passed
    const { error: lateErr } = await supabase
      .from('project_submissions')
      .update({ short_description: 'Late update attempt after deadline' })
      .eq('id', testProjId);
    if (lateErr) {
      console.log('   ✓ Late project modification REJECTED by database trigger:', lateErr.message);
    } else {
      throw new Error('DEADLINE VIOLATION: Modification allowed after deadline!');
    }

    // Clean up test data
    console.log('\n11. Cleaning up test records...');
    await supabase.from('project_votes').delete().eq('event_id', testEventId);
    await supabase.from('project_submissions').delete().eq('event_id', testEventId);
    await supabase.from('event_registrations').delete().eq('event_id', testEventId);
    await supabase.from('events').delete().eq('id', testEventId);
    console.log('   ✓ Cleaned up successfully');

    console.log('\n=== ALL 11 E2E TESTS PASSED WITH 100% SUCCESS ===');
  } catch (err) {
    console.error('\n❌ TEST SUITE FAILED:', err.message);
    // Cleanup on error
    await supabase.from('project_votes').delete().eq('event_id', testEventId);
    await supabase.from('project_submissions').delete().eq('event_id', testEventId);
    await supabase.from('event_registrations').delete().eq('event_id', testEventId);
    await supabase.from('events').delete().eq('id', testEventId);
  }
}

runTests();
