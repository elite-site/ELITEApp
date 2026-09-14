import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

const eventsData = [
  {
    title: 'Vibe Coding',
    description: 'Vibe Coding is a technical team-based event where participants identify a real-world problem, build a working technology solution, and present it live to a panel of judges.\n\nAccepted project types include: Application, Website, Software, AI tool, Hardware project, Automation tool, Technical solution, Physical prototype.',
    category: 'Technical',
    event_type: 'team',
    venue: 'IT Lab',
    event_date: '2026-09-15',
    start_time: '09:15:00',
    end_time: '10:30:00',
    registration_enabled: true,
    submission_enabled: true,
    submission_deadline: '2026-09-15T09:05:00+05:30', // 10 minutes prior to event start
    voting_enabled: false,
    status: 'draft',
    instructions: `• Team size: Minimum 2, Maximum 4 members.
• All team members must actively participate in the presentation and demonstration.
• Teams must register with team name and member details.
• Mandatory Submissions:
  1. Public GitHub Repository Link (complete source code, public repository, clear README)
  2. Deployment / Live Demo Link (publicly accessible, live during presentation)
• A team without both required links submitted before the event will not be allowed to present.
• Presentation: Total team slot is 5 minutes (Problem Statement, Proposed Solution, Application/Project, Working & Implementation, Use Case/Application, Future Scope).
• Equipment: Participants are responsible for bringing their own laptop, charger, USB cables, sensors, microcontrollers, hardware components, adapters, and other project-specific equipment. Organizers provide venue and basic facilities.
• Originality: Project must be original. Plagiarism may result in disqualification.
• Professionalism: Formal/professional dress code and conduct required.
• Decisions: Coordinator and judge decisions are final.`,
    coordinators: [
      { name: 'T. Vinay', type: 'faculty', is_primary: true },
      { name: 'K. Phani Kumar', type: 'student', is_primary: false },
      { name: 'SK. Karishma', type: 'student', is_primary: false, matchRoll: '23K61A12B3' }
    ]
  },
  {
    title: 'Debugging',
    description: 'Individual technical competition focused on identifying and fixing errors in C language programs within a controlled lab environment. Participants receive approximately 10–15 programs with syntax, logical, runtime, compilation, or incorrect output errors to debug and correct.',
    category: 'Technical',
    event_type: 'individual',
    venue: 'IT Lab',
    event_date: '2026-09-15',
    start_time: '10:45:00',
    end_time: '11:45:00',
    registration_enabled: true,
    submission_enabled: false,
    submission_deadline: null,
    voting_enabled: false,
    status: 'draft',
    instructions: `• Individual participation only.
• Language: C only.
• Environment: Controlled IT Lab environment using assigned computer and permitted safe browser/resources only.
• Format: Participants receive approximately 10–15 programs/errors/problems (syntax errors, logical errors, runtime errors, compilation errors, incorrect output).
• Objective: Identify and correct errors so the program compiles and produces expected output.
• Competition Time: 15 minutes.
• Evaluation Criteria: Speed and Accuracy.
• Strict Rules: No unauthorized websites, applications, files, external devices, or mobile phones. No copying or communication with participants.
• Submission: Submit corrected programs as instructed. Stop immediately when time expires.
• Disqualification: Attempts to bypass rules result in disqualification. Judge/coordinator decision is final.`,
    coordinators: [
      { name: 'K. Rammohana Rao', type: 'faculty', is_primary: true },
      { name: 'M. Vamsi', type: 'student', is_primary: false },
      { name: 'V. Rohith', type: 'student', is_primary: false }
    ]
  },
  {
    title: 'Tech Quiz',
    description: 'Individual technical quiz competition conducted on a dedicated online platform across two competitive rounds to test comprehensive computer science and IT knowledge.',
    category: 'Technical',
    event_type: 'individual',
    venue: 'IT Lab',
    event_date: '2026-09-15',
    start_time: '11:55:00',
    end_time: '12:50:00',
    registration_enabled: true,
    submission_enabled: false,
    submission_deadline: null,
    voting_enabled: false,
    status: 'draft',
    instructions: `• Individual participation only.
• Platform: Dedicated online quiz platform provided by organizers.
• Round 1 (Qualifying Round): All registered participants attempt the quiz simultaneously. Top scorers advance to Round 2.
• Round 2 (Final Round): Shortlisted participants attempt a second higher-difficulty quiz.
• Topics Covered: Programming, Data Structures, Algorithms, Networking, Operating Systems, Databases, Web Technologies, AI/ML Basics, General IT Knowledge.
• Rules: No external assistance, no mobile phones, no personal devices, no external resources, and no communication with other participants.
• Disqualification: Unfair means will result in immediate disqualification. Platform scores are final for shortlisting. Judge/coordinator decision is final.`,
    coordinators: [
      { name: 'U. Srinadh', type: 'faculty', is_primary: true },
      { name: 'K. Sarvagna', type: 'student', is_primary: false, matchRoll: '24K61A1244' },
      { name: 'V. Rishikesh', type: 'student', is_primary: false }
    ]
  },
  {
    title: 'Idea Pitch',
    description: 'Technical idea pitching competition where student teams present innovative technological concepts to address real-world challenges using the official organizer-provided presentation template.',
    category: 'Technical',
    event_type: 'team',
    venue: 'IT Lab',
    event_date: '2026-09-15',
    start_time: '12:50:00',
    end_time: '13:45:00',
    registration_enabled: true,
    submission_enabled: true,
    submission_deadline: '2026-09-15T12:40:00+05:30', // 10 minutes prior to event start
    voting_enabled: false,
    status: 'draft',
    instructions: `• Team size: Minimum 2, Maximum 4 members. All team members must be present.
• Duration: 55 minutes total schedule (suited for up to 10 teams).
• Slot Structure: 5 minutes total per team (3 minutes presentation + 2 minutes Q&A).
• Schedule Flow: 5 minutes opening briefing/setup, team presentations, 5 minutes ending judge scoring/wrap-up.
• Presentation Template: Teams MUST use the official organizer-provided PPT template (custom templates are strictly not allowed).
• Submission: Official PPT must be submitted before the event begins.
• Presentation Content: Must cover Idea Overview, Problem it Solves, Proposed Solution, Uniqueness, Impact, Feasibility.
• Rules: Idea must be original; plagiarism results in disqualification. Formal/professional dress code required. Follow coordinator and judge instructions. Judge decision is final.`,
    coordinators: [] // NOT ASSIGNED — Left empty/NULL
  },
  {
    title: 'Art Gallery',
    description: 'Exhibition and voting showcase for individual creative artwork created by students. Detailed rules and regulations were not provided in the source document and can be configured by Admin.',
    category: 'Creative',
    event_type: 'individual',
    venue: 'Class Room (Available)',
    event_date: '2026-09-15',
    start_time: '13:45:00',
    end_time: '14:10:00',
    registration_enabled: true,
    submission_enabled: true,
    submission_deadline: '2026-09-15T13:35:00+05:30',
    voting_enabled: true,
    voting_start: '2026-09-15T13:45:00+05:30',
    voting_end: '2026-09-15T14:10:00+05:30',
    status: 'draft',
    instructions: `• Participation: Individual only.
• Artwork Exhibition: Supports submission of artwork title, description, and high-resolution image upload.
• Review & Approval: Submissions are reviewed and approved by administrators before display in the public gallery.
• Voting Support: Voting is supported for eligible voters. The system strictly enforces one user = one vote per poll.
• Student Privacy: Students see only a confirmation of vote cast ("Voted") and do not see live totals, percentages, rankings, or winners. Admin has access to full voting analytics.
• Note: Detailed rules and regulations were not provided in the source document. Specific artwork restrictions and judging criteria will be configured by Admin.`,
    coordinators: [
      { name: 'M. Tangamani', type: 'faculty', is_primary: true },
      { name: 'Ch. Jhansi', type: 'student', is_primary: false, matchRoll: '23K61A1226' },
      { name: 'M. Srisha', type: 'student', is_primary: false, matchRoll: '24K61A1274' }
    ]
  },
  {
    title: 'Screened Performance',
    description: 'Singing & Mime / Narrative Dance - Video Screening event. There are NO live performances; all entries are pre-recorded video screenings submitted across two categories.',
    category: 'Cultural',
    event_type: 'individual',
    venue: 'AIML Seminar Hall',
    event_date: '2026-09-15',
    start_time: '15:00:00',
    end_time: '15:30:00',
    registration_enabled: true,
    submission_enabled: true,
    submission_deadline: '2026-09-15T14:50:00+05:30',
    voting_enabled: false,
    status: 'draft',
    instructions: `• Participation: Individual only.
• Categories:
  1. Singing
  2. Mime / Narrative Dance
• Entry Rules: A participant may submit one singing entry, one dance/mime entry, or both. Each category is judged separately.
• Performance Format: Pre-recorded videos only — NO live performances will take place.
• Video Technical Requirements:
  - Maximum duration: 2 minutes per entry
  - Accepted formats: MP4, MOV
  - Minimum resolution: 720p HD
  - Audio: Clear audio recording
  - Background music: Allowed for dance/mime entries
• Singing Specific Rules:
  - Participant must actually be the singer (lip-sync-only videos are NOT accepted)
  - Any language allowed
  - Background music / karaoke track allowed
  - Judging criteria: Voice quality, pitch, rhythm, expression, overall performance
• Mime / Narrative Dance Specific Rules:
  - Accepted forms: Classical, folk, contemporary, and expressive dance
  - Background music: Allowed and encouraged
  - Judging criteria: Expression, coordination, creativity, theme relevance, overall presentation
• General Rules:
  - Performance must be the participant's own original performance. Plagiarism results in disqualification.
  - Obscene, offensive, or inappropriate content is strictly prohibited.
  - Videos exceeding 2 minutes may be trimmed.
  - Late submissions will not be accepted.`,
    coordinators: [
      { name: 'Dr. AVN Chandra Sekhar', type: 'faculty', is_primary: true },
      { name: 'G. Saraswathi', type: 'faculty', is_primary: false },
      { name: 'Ch. Jhansi', type: 'student', is_primary: false, matchRoll: '23K61A1226' },
      { name: 'J. Likitha', type: 'student', is_primary: false },
      { name: 'M. Srisha', type: 'student', is_primary: false, matchRoll: '24K61A1274' },
      { name: 'K. Sarvagna', type: 'student', is_primary: false, matchRoll: '24K61A1244' }
    ]
  },
  {
    title: 'Meme Mania',
    description: 'Individual tech-themed meme competition. Participants submit an original, pre-made technology meme for screening and evaluation.',
    category: 'Creative',
    event_type: 'individual',
    venue: 'Screening Hall',
    event_date: null, // Source document specifies "Saturday" but does not give a specific calendar date. Left strictly NULL!
    start_time: '15:00:00',
    end_time: '16:30:00',
    registration_enabled: true,
    submission_enabled: true,
    submission_deadline: null, // Not specified in source. Left NULL.
    voting_enabled: false,
    status: 'draft',
    instructions: `• Participation: Individual only.
• Entry Limit: One meme entry per participant.
• Submission: Pre-made meme submitted in advance; on-the-spot creation is NOT allowed.
• Theme: Technology (e.g., Programming, IT, Computers, Software, Engineering).
• Accepted Formats: PNG, JPG, GIF.
• Originality: Must be original and created by the participant.
• Schedule: Saturday, 3:00 PM – 4:30 PM (Specific calendar date to be determined by Admin).
• Judging Criteria: Creativity, originality, humour, entertainment value, technology relevance, overall presentation, image quality.
• Content Guidelines: Explicit, hateful, offensive, or politically sensitive content is strictly prohibited.
• Submission platform & deadline: To be announced by Admin.
• Rules: Late submissions will not be accepted. Judge decision is final.`,
    coordinators: [
      { name: 'V. Lohith', type: 'student', is_primary: false, matchRoll: '23K61A12C5' },
      { name: 'K. Ganapathi', type: 'student', is_primary: false, matchRoll: '23K61A1266' }
      // Faculty coordinator: NOT ASSIGNED — Left NULL
    ]
  }
];

async function importEvents() {
  console.log('================================================================');
  console.log('🚀 IMPORTING ELITE TECHNICAL EVENTS INTO SUPABASE');
  console.log('================================================================\n');

  const client = new Client({ connectionString: CONN, ssl: { rejectUnauthorized: false } });
  await client.connect();

  // Find admin profile ID for created_by
  const adminRes = await client.query("SELECT id FROM public.profiles WHERE role = 'admin' LIMIT 1");
  const adminId = adminRes.rows[0]?.id || null;
  console.log(`Admin Creator ID: ${adminId}`);

  // Fetch student profiles for matching
  const profilesRes = await client.query("SELECT id, roll_number, full_name FROM public.profiles");
  const profilesByRoll = new Map();
  profilesRes.rows.forEach(p => profilesByRoll.set(p.roll_number, p.id));

  let importedCount = 0;
  let coordinatorsCount = 0;

  for (const ev of eventsData) {
    console.log(`\nImporting Event: "${ev.title}"...`);

    // Check if event already exists
    const existingEv = await client.query("SELECT id FROM public.events WHERE title = $1", [ev.title]);
    let eventId;

    if (existingEv.rows.length > 0) {
      eventId = existingEv.rows[0].id;
      console.log(`  -> Event already exists (ID: ${eventId}). Updating definition...`);
      await client.query(`
        UPDATE public.events SET
          description = $1,
          category = $2,
          event_type = $3,
          venue = $4,
          event_date = $5,
          start_time = $6,
          end_time = $7,
          registration_enabled = $8,
          submission_enabled = $9,
          submission_deadline = $10,
          voting_enabled = $11,
          voting_start = $12,
          voting_end = $13,
          status = $14,
          instructions = $15,
          updated_at = NOW()
        WHERE id = $16
      `, [
        ev.description,
        ev.category,
        ev.event_type,
        ev.venue,
        ev.event_date,
        ev.start_time,
        ev.end_time,
        ev.registration_enabled,
        ev.submission_enabled,
        ev.submission_deadline,
        ev.voting_enabled,
        ev.voting_start || null,
        ev.voting_end || null,
        ev.status,
        ev.instructions,
        eventId
      ]);
    } else {
      const insertRes = await client.query(`
        INSERT INTO public.events (
          title,
          description,
          category,
          event_type,
          venue,
          event_date,
          start_time,
          end_time,
          registration_enabled,
          submission_enabled,
          submission_deadline,
          voting_enabled,
          voting_start,
          voting_end,
          status,
          instructions,
          created_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
        RETURNING id
      `, [
        ev.title,
        ev.description,
        ev.category,
        ev.event_type,
        ev.venue,
        ev.event_date,
        ev.start_time,
        ev.end_time,
        ev.registration_enabled,
        ev.submission_enabled,
        ev.submission_deadline,
        ev.voting_enabled,
        ev.voting_start || null,
        ev.voting_end || null,
        ev.status,
        ev.instructions,
        adminId
      ]);
      eventId = insertRes.rows[0].id;
      importedCount++;
      console.log(`  -> Created Event successfully (ID: ${eventId})`);
    }

    // Insert coordinators
    for (const c of ev.coordinators) {
      const staffId = c.matchRoll ? profilesByRoll.get(c.matchRoll) || null : null;

      await client.query(`
        INSERT INTO public.event_coordinators (
          event_id,
          coordinator_name,
          coordinator_type,
          is_primary,
          staff_id
        ) VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (event_id, coordinator_name, coordinator_type)
        DO UPDATE SET
          is_primary = EXCLUDED.is_primary,
          staff_id = EXCLUDED.staff_id
      `, [
        eventId,
        c.name,
        c.type,
        c.is_primary,
        staffId
      ]);
      coordinatorsCount++;
      console.log(`     + Coordinator: [${c.type.toUpperCase()}${c.is_primary ? ' - PRIMARY' : ''}] ${c.name} ${staffId ? `(Linked Profile: ${staffId})` : '(Profile: Unlinked/NULL)'}`);
    }
  }

  console.log('\n================================================================');
  console.log(`✅ EVENT IMPORT COMPLETED: ${eventsData.length} Events, ${coordinatorsCount} Coordinator Mappings`);
  console.log('================================================================\n');

  await client.end();
}

importEvents().catch(console.error);
