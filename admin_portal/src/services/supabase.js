import { createClient } from '@supabase/supabase-js';

// ─── Supabase Direct Connection ───────────────────────────────────────────────
const SUPABASE_URL = 'https://qjntsxlmdrldbnvmqpca.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqbnRzeGxtZHJsZGJudm1xcGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxODAxODksImV4cCI6MjEwNDc1NjE4OX0.wzkJ2LQz8vxAtA9ylrNbqm6P7uwiZ2GcxcG-g3Gig_o';

class SupabaseAdminService {
  constructor() {
    this.url = SUPABASE_URL;
    this.key = SUPABASE_ANON_KEY;
    this.client = createClient(this.url, this.key, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
      },
    });
  }

  get supabase() {
    return this.client;
  }

  updateCredentials(newUrl, newKey) {
    this.url = newUrl;
    this.key = newKey;
    this.client = createClient(newUrl, newKey, {
      auth: { persistSession: true, autoRefreshToken: true },
    });
  }

  resetCredentials() {
    this.updateCredentials(SUPABASE_URL, SUPABASE_ANON_KEY);
  }

  async testConnection() {
    try {
      const { data, error } = await this.client.from('events').select('id').limit(1);
      if (error) throw error;
      return { ok: true, data };
    } catch (e) {
      return { ok: false, error: e.message || String(e) };
    }
  }

  // ─── Metrics & Dashboard Summary ───
  async getDashboardMetrics() {
    const c = this.client;

    const [
      { count: studentsCount },
      { count: staffCount },
      { count: eventsCount },
      { count: registrationsCount },
      { count: attendanceCount },
      { count: pollsCount },
      { count: projectsCount },
    ] = await Promise.all([
      c.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'student'),
      c.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'staff'),
      c.from('events').select('*', { count: 'exact', head: true }),
      c.from('event_registrations').select('*', { count: 'exact', head: true }),
      c.from('event_attendance').select('*', { count: 'exact', head: true }),
      c.from('polls').select('*', { count: 'exact', head: true }).eq('is_active', true),
      c.from('project_submissions').select('*', { count: 'exact', head: true }),
    ]);

    return {
      students: studentsCount ?? 0,
      staff: staffCount ?? 0,
      events: eventsCount ?? 0,
      registrations: registrationsCount ?? 0,
      attendanceToday: attendanceCount ?? 0,
      openPolls: pollsCount ?? 0,
      openTickets: projectsCount ?? 0,
    };
  }

  // ─── Students Operations (From Profiles) ───
  async getStudents({ search = '', year = 'All', limit = 100, page = 0 } = {}) {
    let query = this.client.from('profiles').select('*', { count: 'exact' }).eq('role', 'student');

    if (year && year !== 'All') {
      query = query.ilike('year', `%${year}%`);
    }

    if (search && search.trim()) {
      const q = search.trim();
      query = query.or(`roll_number.ilike.%${q}%,full_name.ilike.%${q}%,email.ilike.%${q}%`);
    }

    const from = page * limit;
    const to = from + limit - 1;
    const { data, count, error } = await query
      .order('roll_number', { ascending: true })
      .range(from, to);

    if (error) throw error;

    const formatted = (data || []).map((s) => ({
      id: s.id,
      roll_no: s.roll_number,
      name: s.full_name,
      email: s.email || `${s.roll_number.toLowerCase()}@sasi.ac.in`,
      department: s.department || 'Information Technology',
      year_level: s.year || '3rd Year',
      section: s.section || 'A',
      status: s.is_active ? 'ACTIVE' : 'INACTIVE',
      qr_token: `ELITE_QR_${s.roll_number}`,
    }));

    return { students: formatted, total: count || 0 };
  }

  async addStudent(student) {
    const roll = student.roll_no.toUpperCase().trim();
    const email = student.email || `${roll.toLowerCase()}@sasi.ac.in`;

    // 1. Create or retrieve auth user
    let userId = student.id;
    if (!userId) {
      // Use execute_sql_query RPC to securely provision student in auth.users
      const userRes = await this.executeSql(`
        INSERT INTO auth.users (
          id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at
        ) VALUES (
          gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '${email}',
          crypt('${roll.toLowerCase()}', gen_salt('bf')), NOW(), NOW(), NOW()
        ) RETURNING id;
      `);
      if (userRes && userRes[0]) {
        userId = userRes[0].id;
      }
    }

    const { data, error } = await this.client.from('profiles').upsert({
      id: userId,
      roll_number: roll,
      full_name: student.name,
      email,
      department: student.department || 'Information Technology',
      year: student.year_level || '3rd Year',
      section: student.section || 'A',
      role: 'student',
      is_active: student.status !== 'INACTIVE',
    }).select();

    if (error) throw error;
    return data;
  }

  async updateStudent(rollNo, updates) {
    const payload = {};
    if (updates.name) payload.full_name = updates.name;
    if (updates.email) payload.email = updates.email;
    if (updates.department) payload.department = updates.department;
    if (updates.year_level) payload.year = updates.year_level;
    if (updates.section) payload.section = updates.section;
    if (updates.status !== undefined) payload.is_active = updates.status === 'ACTIVE';

    const { data, error } = await this.client
      .from('profiles')
      .update(payload)
      .eq('roll_number', rollNo)
      .select();

    if (error) throw error;
    return data;
  }

  async deleteStudent(rollNo) {
    const { data: student } = await this.client
      .from('profiles')
      .select('id')
      .eq('roll_number', rollNo)
      .single();

    if (student?.id) {
      await this.executeSql(`DELETE FROM auth.users WHERE id = '${student.id}'`);
    } else {
      await this.client.from('profiles').delete().eq('roll_number', rollNo);
    }
    return true;
  }

  // ─── Staff Operations (From Profiles) ───
  async getStaff() {
    const { data, error } = await this.client
      .from('profiles')
      .select('*')
      .eq('role', 'staff')
      .order('roll_number', { ascending: true });

    if (error) throw error;

    return (data || []).map((st) => ({
      id: st.id,
      employee_id: st.roll_number,
      name: st.full_name,
      email: st.email || `${st.roll_number.toLowerCase()}@sasi.ac.in`,
      department: st.department,
      phone: st.phone || '',
      designation: 'Assistant Professor',
      cabin: 'IT Staff Room',
    }));
  }

  async addStaff(staffMember) {
    const empId = staffMember.employee_id.toUpperCase().trim();
    const email = staffMember.email || `${empId.toLowerCase()}@sasi.ac.in`;

    const userRes = await this.executeSql(`
      INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '${email}',
        crypt('${empId.toLowerCase()}', gen_salt('bf')), NOW(), NOW(), NOW()
      ) RETURNING id;
    `);

    const userId = userRes?.[0]?.id || `u_staff_${empId.toLowerCase()}`;

    const { data, error } = await this.client.from('profiles').upsert({
      id: userId,
      roll_number: empId,
      full_name: staffMember.name,
      email,
      department: staffMember.department || 'Information Technology',
      phone: staffMember.phone,
      role: 'staff',
      is_active: true,
    }).select();

    if (error) throw error;
    return data;
  }

  async updateStaff(employeeId, updates) {
    const payload = {};
    if (updates.name) payload.full_name = updates.name;
    if (updates.email) payload.email = updates.email;
    if (updates.phone) payload.phone = updates.phone;
    if (updates.department) payload.department = updates.department;

    const { data, error } = await this.client
      .from('profiles')
      .update(payload)
      .eq('roll_number', employeeId)
      .select();

    if (error) throw error;
    return data;
  }

  async deleteStaff(employeeId) {
    const { data: staff } = await this.client
      .from('profiles')
      .select('id')
      .eq('roll_number', employeeId)
      .single();

    if (staff?.id) {
      await this.executeSql(`DELETE FROM auth.users WHERE id = '${staff.id}'`);
    } else {
      await this.client.from('profiles').delete().eq('roll_number', employeeId);
    }
    return true;
  }

  // ─── Events Operations ───
  async getEvents() {
    const { data, error } = await this.client
      .from('events')
      .select('*, event_registrations(count), event_coordinators(*)')
      .order('start_time', { ascending: true });

    if (error) throw error;

    return (data || []).map((ev) => {
      const coords = ev.event_coordinators || [];
      const faculty = coords
        .filter((c) => c.coordinator_type === 'faculty')
        .map((c) => `${c.coordinator_name}${c.is_primary ? ' (Primary)' : ''}`)
        .join(', ');
      const students = coords
        .filter((c) => c.coordinator_type === 'student')
        .map((c) => c.coordinator_name)
        .join(', ');

      return {
        ...ev,
        registered_count: ev.event_registrations?.[0]?.count ?? 0,
        banner_url: ev.image_url,
        rules: ev.instructions || '',
        faculty_coordinators: faculty || 'None Assigned',
        student_coordinators: students || 'None Assigned',
        participation_type: ev.event_type === 'team' ? 'Team (2-4 Members)' : 'Individual',
      };
    });
  }

  async createEvent(event) {
    const { data, error } = await this.client.from('events').insert({
      title: event.title,
      description: event.description || '',
      category: event.category || 'Technical',
      event_type: (event.event_type || 'individual').toLowerCase().includes('team') ? 'team' : 'individual',
      image_url: event.banner_url || event.image_url || null,
      venue: event.venue || 'Campus Auditorium',
      event_date: event.event_date || new Date().toISOString().split('T')[0],
      start_time: event.start_time || '10:00:00',
      end_time: event.end_time || '16:00:00',
      instructions: event.rules || event.instructions || '',
      prize_details: event.prize_details || null,
      status: event.status ? event.status.toLowerCase() : 'published',
      registration_enabled: true,
      is_project_submission_enabled: event.is_project_submission_enabled ?? false,
      submission_enabled: event.is_project_submission_enabled ?? false,
      submission_deadline: event.project_submission_deadline || null,
      voting_enabled: event.is_voting_enabled ?? false,
    }).select();

    if (error) throw error;
    return data;
  }

  async updateEvent(id, updates) {
    const payload = { ...updates };
    if (payload.banner_url) {
      payload.image_url = payload.banner_url;
      delete payload.banner_url;
    }
    if (payload.status) {
      payload.status = payload.status.toLowerCase();
    }
    const { data, error } = await this.client.from('events').update(payload).eq('id', id).select();
    if (error) throw error;
    return data;
  }

  async deleteEvent(id) {
    const { error } = await this.client.from('events').delete().eq('id', id);
    if (error) throw error;
    return true;
  }

  // ─── Attendance Operations ───
  async getAttendanceLogs({ limit = 50 } = {}) {
    const { data, error } = await this.client
      .from('event_attendance')
      .select('*, events(title), profiles(full_name, roll_number)')
      .order('scanned_at', { ascending: false })
      .limit(limit);

    if (error) throw error;

    return (data || []).map((a) => ({
      id: a.id,
      event_id: a.events?.title || a.event_id,
      student_roll: a.profiles?.roll_number || 'N/A',
      student_name: a.profiles?.full_name || 'Student Access',
      status: a.status.toUpperCase(),
      session: a.session,
      scanned_by: a.scanned_by || 'Turnstile Gate #2',
      scanned_at: a.scanned_at,
    }));
  }

  async logAttendance({ studentId, studentRoll, eventId, room = 'Turnstile Gate #2', status = 'present' }) {
    // Lookup profile if studentId not provided
    let sId = studentId;
    if (!sId && studentRoll) {
      const { data: prof } = await this.client
        .from('profiles')
        .select('id')
        .eq('roll_number', studentRoll.toUpperCase().trim())
        .single();
      sId = prof?.id;
    }

    if (!sId) throw new Error(`Student with Roll No ${studentRoll} not found in database.`);

    const { data, error } = await this.client.from('event_attendance').insert({
      event_id: eventId,
      student_id: sId,
      status: status.toLowerCase(),
      session: room,
      scanned_at: new Date().toISOString(),
    }).select();

    if (error) throw error;
    return data;
  }

  async deleteAttendance(attendanceId) {
    const { error } = await this.client.from('event_attendance').delete().eq('id', attendanceId);
    if (error) throw error;
    return true;
  }

  // ─── Polls Operations ───
  async getPolls() {
    const { data, error } = await this.client
      .from('polls')
      .select('*, poll_options(*)')
      .order('created_at', { ascending: false });

    if (error) throw error;

    return (data || []).map((p) => ({
      id: p.id,
      question: p.title,
      description: p.description,
      category: 'Campus Poll',
      status: p.is_active ? 'OPEN' : 'CLOSED',
      total_votes: 0,
      created_at: p.created_at,
      poll_options: (p.poll_options || []).map((o) => ({
        id: o.id,
        text: o.title,
        vote_count: 0,
        description: o.description,
      })),
    }));
  }

  async createPoll({ question, description, category, options = [] }) {
    const { data: poll, error: pollError } = await this.client.from('polls').insert({
      title: question,
      description,
      is_active: true,
      created_at: new Date().toISOString(),
    }).select().single();

    if (pollError) throw pollError;

    if (options.length > 0) {
      const optionRows = options.map((opt, idx) => ({
        poll_id: poll.id,
        title: typeof opt === 'string' ? opt : opt.text || `Option ${idx + 1}`,
        description: typeof opt === 'object' ? opt.description : null,
        display_order: idx,
      }));
      await this.client.from('poll_options').insert(optionRows);
    }

    return poll.id;
  }

  async updatePollStatus(pollId, is_active) {
    const { error } = await this.client.from('polls').update({ is_active }).eq('id', pollId);
    if (error) throw error;
    return true;
  }

  async deletePoll(pollId) {
    const { error } = await this.client.from('polls').delete().eq('id', pollId);
    if (error) throw error;
    return true;
  }

  async uploadPollImage(file) {
    const ext = file.name.split('.').pop();
    const fileName = `poll_${Date.now()}_${Math.random().toString(36).substr(2, 6)}.${ext}`;
    const { error } = await this.client.storage.from('poll-images').upload(fileName, file);
    if (error) throw error;
    const { data: { publicUrl } } = this.client.storage.from('poll-images').getPublicUrl(fileName);
    return publicUrl;
  }

  async deleteRegistration(registrationId) {
    const { error } = await this.client.from('event_registrations').delete().eq('id', registrationId);
    if (error) throw error;
    return true;
  }

  async getEventRegistrations(eventId) {
    const { data, error } = await this.client
      .from('event_registrations')
      .select('*, profiles(id, full_name, roll_number), teams(*, team_members(*, profiles(id, full_name, roll_number)))')
      .eq('event_id', eventId)
      .order('registered_at', { ascending: false });

    if (error) throw error;

    return (data || []).map((r) => {
      const isTeam = !!r.team_id;
      const team = r.teams;
      const members = team?.team_members?.map((tm) => ({
        studentId: tm.student_id,
        studentName: tm.profiles?.full_name || 'Member',
        studentRoll: tm.profiles?.roll_number || '',
        isLeader: tm.is_leader,
      })) || [];

      return {
        id: r.id,
        user_id: r.user_id,
        student_name: r.profiles?.full_name || 'Student',
        student_roll: r.profiles?.roll_number || '',
        is_team_registration: isTeam,
        team_name: team?.team_name || null,
        members: members.length > 0 ? members : [{
          studentId: r.user_id,
          studentName: r.profiles?.full_name || 'Student',
          studentRoll: r.profiles?.roll_number || '',
          isLeader: true,
        }],
        registered_at: r.registered_at,
      };
    });
  }

  // ─── Project Submissions Operations ───
  async getProjectSubmissions(eventId) {
    const { data, error } = await this.client
      .from('project_submissions')
      .select('*, teams(team_name), profiles:submitted_by(full_name, roll_number), project_images(*)')
      .eq('event_id', eventId)
      .order('submitted_at', { ascending: false });

    if (error) throw error;

    return (data || []).map((p) => ({
      id: p.id,
      event_id: p.event_id,
      team_id: p.team_id,
      team_name: p.teams?.team_name || p.profiles?.full_name || 'Participant',
      project_name: p.project_title || 'Untitled Project',
      project_title: p.project_title || 'Untitled Project',
      description: p.description || '',
      problem_statement: p.problem_statement || '',
      proposed_solution: p.proposed_solution || '',
      technologies_used: p.technologies_used || [],
      github_url: p.github_url || '',
      live_demo_url: p.live_demo_url || '',
      presentation_url: p.presentation_url || '',
      status: (p.status || (p.is_published ? 'PUBLISHED' : 'PENDING')).toUpperCase(),
      is_published: p.is_published || false,
      submitted_at: p.submitted_at,
      images: (p.project_images || []).map((img) => img.image_url),
    }));
  }

  async publishProjectSubmission(submissionId) {
    const { data, error } = await this.client
      .from('project_submissions')
      .update({ is_published: true, status: 'approved' })
      .eq('id', submissionId)
      .select();
    if (error) throw error;
    return data;
  }

  async unpublishProjectSubmission(submissionId) {
    const { data, error } = await this.client
      .from('project_submissions')
      .update({ is_published: false, status: 'pending' })
      .eq('id', submissionId)
      .select();
    if (error) throw error;
    return data;
  }

  async getProjectVotingResults(eventId) {
    try {
      const { data: polls } = await this.client
        .from('polls')
        .select('id')
        .eq('title', eventId)
        .limit(1);

      const pollId = polls?.[0]?.id;
      if (!pollId) {
        return { totalVotes: 0, projects: [] };
      }

      const { data: options } = await this.client
        .from('poll_options')
        .select('id, title, description, poll_votes(count)')
        .eq('poll_id', pollId);

      const projects = (options || []).map((o) => ({
        id: o.id,
        project_name: o.title,
        team_name: o.description || 'Entry',
        vote_count: o.poll_votes?.[0]?.count ?? 0,
      }));

      const totalVotes = projects.reduce((acc, curr) => acc + (curr.vote_count || 0), 0);
      return { totalVotes, projects };
    } catch (e) {
      return { totalVotes: 0, projects: [] };
    }
  }

  // ─── Realtime Subscriptions ───
  subscribeToRegistrations(callback) {
    const channelId = `admin_regs_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    const channel = this.client
      .channel(channelId)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'event_registrations' },
        (payload) => callback(payload)
      )
      .subscribe();

    return () => this.client.removeChannel(channel);
  }

  subscribeToEvents(callback) {
    const channelId = `admin_evs_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    const channel = this.client
      .channel(channelId)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'events' },
        (payload) => callback(payload)
      )
      .subscribe();

    return () => this.client.removeChannel(channel);
  }

  subscribeToPollVotes(callback) {
    const channelId = `admin_pvotes_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    const channel = this.client
      .channel(channelId)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'poll_votes' },
        (payload) => callback(payload)
      )
      .subscribe();

    return () => this.client.removeChannel(channel);
  }

  subscribeToProjectSubmissions(eventId, callback) {
    const channelId = `admin_subs_${eventId}_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    const channel = this.client
      .channel(channelId)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'project_submissions' },
        (payload) => callback(payload)
      )
      .subscribe();

    return () => this.client.removeChannel(channel);
  }

  subscribeToProjectVotes(eventId, callback) {
    const channelId = `admin_pvotes_ev_${eventId}_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    const channel = this.client
      .channel(channelId)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'poll_votes' },
        (payload) => callback(payload)
      )
      .subscribe();

    return () => this.client.removeChannel(channel);
  }

  // ─── Helpdesk Tickets Operations ───
  async getTickets() {
    try {
      const { data, error } = await this.client.from('tickets').select('*');
      if (!error && data) return data;
    } catch (_) {}
    return [];
  }

  async updateTicketStatus(ticketId, newStatus, mentor) {
    try {
      await this.client.from('tickets').update({ status: newStatus, mentor }).eq('id', ticketId);
    } catch (_) {}
    return true;
  }

  // ─── Notifications & Broadcasts ───
  async getNotifications() {
    try {
      const { data, error } = await this.client.from('notifications').select('*').order('created_at', { ascending: false });
      if (!error && data) return data;
    } catch (_) {}
    return [];
  }

  async broadcastNotification({ title, message, category, target_audience }) {
    try {
      await this.client.from('notifications').insert({
        title,
        message,
        category,
        target_audience,
        created_at: new Date().toISOString(),
      });
    } catch (_) {}
    return true;
  }

  // ─── Direct Database Management & Dynamic Table Operations ───
  getTableDefinitions() {
    return [
      { name: 'events', pk: 'id', label: 'Events', desc: 'College events and technical competitions' },
      { name: 'profiles', pk: 'id', altPk: 'roll_number', label: 'Profiles', desc: 'Student, staff, and admin profiles' },
      { name: 'event_registrations', pk: 'id', label: 'Registrations', desc: 'Individual and team event registrations' },
      { name: 'teams', pk: 'id', label: 'Teams', desc: 'Event teams (2 to 4 members)' },
      { name: 'team_members', pk: 'id', label: 'Team Members', desc: 'Team membership and leader designations' },
      { name: 'event_coordinators', pk: 'id', label: 'Event Coordinators', desc: 'Faculty coordinators assigned to events' },
      { name: 'event_registration_fields', pk: 'id', label: 'Custom Form Fields', desc: 'Dynamic per-event registration fields' },
      { name: 'event_registration_answers', pk: 'id', label: 'Form Answers', desc: 'Student responses to custom event form fields' },
      { name: 'project_submissions', pk: 'id', label: 'Project Submissions', desc: 'Hackathon projects and code showcase submissions' },
      { name: 'project_images', pk: 'id', label: 'Project Images', desc: 'Project submission image assets' },
      { name: 'polls', pk: 'id', label: 'Polls', desc: 'Campus opinion polls and showcase voting' },
      { name: 'poll_options', pk: 'id', label: 'Poll Options', desc: 'Choices and candidates for active polls' },
      { name: 'poll_option_images', pk: 'id', label: 'Poll Option Images', desc: 'Option image banners' },
      { name: 'poll_votes', pk: 'id', label: 'Poll Votes', desc: 'Single-vote per user ballot records' },
      { name: 'event_attendance', pk: 'id', label: 'Attendance', desc: 'Event check-in and turnstile access logs' },
    ];
  }

  async getTableCounts() {
    const tables = this.getTableDefinitions();
    const counts = {};
    await Promise.all(
      tables.map(async (t) => {
        try {
          const { count } = await this.client.from(t.name).select('*', { count: 'exact', head: true });
          counts[t.name] = count ?? 0;
        } catch (_) {
          counts[t.name] = 0;
        }
      })
    );
    return counts;
  }

  async getTableRecords(tableName, { page = 0, limit = 50, sortBy = null, ascending = true } = {}) {
    let query = this.client.from(tableName).select('*', { count: 'exact' });

    if (sortBy) {
      query = query.order(sortBy, { ascending });
    }

    const from = page * limit;
    const to = from + limit - 1;
    query = query.range(from, to);

    const { data, count, error } = await query;
    if (error) throw error;
    return { records: data || [], total: count || 0 };
  }

  async insertTableRow(tableName, rowData) {
    const { data, error } = await this.client.from(tableName).insert(rowData).select();
    if (error) throw error;
    return data;
  }

  async updateTableRow(tableName, pkColumn, pkValue, updates) {
    const { data, error } = await this.client.from(tableName).update(updates).eq(pkColumn, pkValue).select();
    if (error) throw error;
    return data;
  }

  async deleteTableRow(tableName, pkColumn, pkValue) {
    const { error } = await this.client.from(tableName).delete().eq(pkColumn, pkValue);
    if (error) throw error;
    return true;
  }

  async executeSql(sqlQuery) {
    const { data, error } = await this.client.rpc('execute_sql_query', {
      query_text: sqlQuery.trim(),
    });
    if (error) throw error;
    if (data && data.error) throw new Error(data.error);
    return data;
  }
}

export const supabaseAdmin = new SupabaseAdminService();
export default supabaseAdmin;
