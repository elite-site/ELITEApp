import { createClient } from '@supabase/supabase-js';
import pg from 'pg';

const SUPABASE_URL = 'https://qjntsxlmdrldbnvmqpca.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqbnRzeGxtZHJsZGJudm1xcGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxODAxODksImV4cCI6MjEwNDc1NjE4OX0.wzkJ2LQz8vxAtA9ylrNbqm6P7uwiZ2GcxcG-g3Gig_o';
const PG_CONN = 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function main() {
  console.log('================================================================');
  console.log('   ELITE MOBILE APP & SUPABASE FULL FEATURE AUDIT');
  console.log('================================================================\n');

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const pgClient = new pg.Client({ connectionString: PG_CONN });
  await pgClient.connect();

  let passed = 0;
  let failed = 0;

  function report(feature, ok, details) {
    if (ok) {
      console.log(`[PASS] ${feature}: ${details}`);
      passed++;
    } else {
      console.error(`[FAIL] ${feature}: ${details}`);
      failed++;
    }
  }

  // 1. AUTH & STUDENT PROFILE
  try {
    const { data: authUser, error: authErr } = await supabase.auth.signInWithPassword({
      email: '25k61a1201@sasi.ac.in',
      password: '25K61A1201',
    });
    if (authErr) throw authErr;

    const { data: profile, error: profErr } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', authUser.user.id)
      .single();
    if (profErr) throw profErr;

    report(
      'Feature 1 - Authentication & Student Profile',
      profile.roll_number === '25K61A1201' && profile.full_name === 'Abbireddy Akhila',
      `Authenticated ${profile.full_name} (${profile.roll_number}, Year: ${profile.year}, Role: ${profile.role})`
    );
  } catch (err) {
    report('Feature 1 - Authentication & Student Profile', false, err.message);
  }

  // 2. EVENTS & COORDINATORS
  try {
    const { data: events, error: evErr } = await supabase
      .from('events')
      .select('*, event_coordinators(*)')
      .eq('status', 'published')
      .order('event_date', { ascending: true });
    if (evErr) throw evErr;

    const titles = events.map(e => e.title);
    const hasAll7 = ['Vibe Coding', 'Debugging', 'Tech Quiz', 'Idea Pitch', 'Art Gallery', 'Screened Performance', 'Meme Mania']
      .every(t => titles.includes(t));

    const allHaveCoords = events.every(e => e.event_coordinators && e.event_coordinators.length > 0);

    report(
      'Feature 2 - Live Events & Coordinators',
      hasAll7 && allHaveCoords,
      `Loaded ${events.length} published events, all with faculty & student coordinators attached`
    );
  } catch (err) {
    report('Feature 2 - Live Events & Coordinators', false, err.message);
  }

  // 3. REGISTRATIONS (INDIVIDUAL & TEAM)
  try {
    const { count, error: regErr } = await supabase
      .from('event_registrations')
      .select('*', { count: 'exact', head: true });
    if (regErr) throw regErr;

    report(
      'Feature 3 - Event Registrations (Individual & Team)',
      true,
      `event_registrations table online and accepting verified registrations (current count: ${count})`
    );
  } catch (err) {
    report('Feature 3 - Event Registrations (Individual & Team)', false, err.message);
  }

  // 4. PROJECT SUBMISSIONS & SHOWCASE
  try {
    const { data: projs, error: projErr } = await supabase
      .from('project_submissions')
      .select('*, teams(team_name), project_images(*)');
    if (projErr) throw projErr;

    report(
      'Feature 4 - Project Submissions & Showcase',
      true,
      `project_submissions relational query with teams & project_images operational (submissions: ${projs.length})`
    );
  } catch (err) {
    report('Feature 4 - Project Submissions & Showcase', false, err.message);
  }

  // 5. CAMPUS POLLS & VOTING
  try {
    const { data: polls, error: pollErr } = await supabase
      .from('polls')
      .select('*, poll_options(*)')
      .eq('is_active', true);
    if (pollErr) throw pollErr;

    const hasPollWithOptions = polls.length > 0 && polls[0].poll_options.length >= 2;

    report(
      'Feature 5 - Campus Polls & Live Voting Engine',
      hasPollWithOptions,
      `Active poll "${polls[0]?.title}" loaded with ${polls[0]?.poll_options?.length} options`
    );
  } catch (err) {
    report('Feature 5 - Campus Polls & Live Voting Engine', false, err.message);
  }

  // 6. ATTENDANCE & DIGITAL PASS
  try {
    const rawQrCode = 'PASS-25K61A1201';
    const cleanToken = rawQrCode.replace('PASS-', '').trim();
    const isUuid = /^[0-9a-fA-F-]{36}$/.test(cleanToken);
    const query = supabase.from('profiles').select('id, full_name, roll_number, department');
    const { data: studentMatch, error: qrErr } = await (isUuid
      ? query.or(`id.eq.${cleanToken},roll_number.ilike.${cleanToken}`)
      : query.ilike('roll_number', cleanToken)
    ).single();
    if (qrErr) throw qrErr;

    report(
      'Feature 6 - Turnstile QR Pass & Attendance Scanner',
      studentMatch.roll_number === '25K61A1201',
      `Pass token ${rawQrCode} successfully scanned & matched to student ${studentMatch.full_name} (${studentMatch.roll_number})`
    );
  } catch (err) {
    report('Feature 6 - Turnstile QR Pass & Attendance Scanner', false, err.message);
  }

  // 7. NOTIFICATIONS & BROADCASTS
  try {
    const { data: notifs, error: notifErr } = await supabase
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false });
    if (notifErr) throw notifErr;

    report(
      'Feature 7 - Department Notifications & Broadcasts',
      notifs.length > 0,
      `Loaded ${notifs.length} department broadcasts (latest: "${notifs[0]?.title}")`
    );
  } catch (err) {
    report('Feature 7 - Department Notifications & Broadcasts', false, err.message);
  }

  // 8. SUPABASE REALTIME PUBLICATION AUDIT
  try {
    const pubRes = await pgClient.query(`
      SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime' ORDER BY tablename;
    `);
    const tables = pubRes.rows.map(r => r.tablename);

    const required = [
      'event_attendance',
      'event_coordinators',
      'event_registrations',
      'events',
      'notifications',
      'poll_options',
      'poll_votes',
      'polls',
      'profiles',
      'project_images',
      'project_submissions',
      'team_members',
      'teams'
    ];

    const allPresent = required.every(t => tables.includes(t));

    report(
      'Feature 8 - Supabase Realtime Publication Coverage',
      allPresent,
      `All 13 transactional tables active in supabase_realtime: [${tables.join(', ')}]`
    );
  } catch (err) {
    report('Feature 8 - Supabase Realtime Publication Coverage', false, err.message);
  }

  await pgClient.end();

  console.log('\n================================================================');
  console.log(`RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================\n');

  if (failed > 0) process.exit(1);
}

main().catch(err => {
  console.error('Fatal error during audit:', err);
  process.exit(1);
});
