import { createClient } from '@supabase/supabase-js';

// ─── Supabase Direct Connection ───────────────────────────────────────────────
const SUPABASE_URL = 'https://qjntsxlmdrldbnvmqpca.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqbnRzeGxtZHJsZGJudm1xcGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxODAxODksImV4cCI6MjEwNDc1NjE4OX0.wzkJ2LQz8vxAtA9ylrNbqm6P7uwiZ2GcxcG-g3Gig_o';

class SupabaseAdminService {
  constructor() {
    this.client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
      },
    });
  }

  async testConnection() {
    try {
      const { data, error } = await this.client.from('academic_years').select('id').limit(1);
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
      { count: ticketsCount },
    ] = await Promise.all([
      c.from('students').select('*', { count: 'exact', head: true }),
      c.from('staff').select('*', { count: 'exact', head: true }),
      c.from('events').select('*', { count: 'exact', head: true }),
      c.from('event_registrations').select('*', { count: 'exact', head: true }).eq('status', 'CONFIRMED'),
      c.from('event_attendance').select('*', { count: 'exact', head: true }),
      c.from('polls').select('*', { count: 'exact', head: true }).eq('status', 'OPEN'),
      c.from('student_queries').select('*', { count: 'exact', head: true }).neq('status', 'RESOLVED'),
    ]);

    return {
      students: studentsCount ?? 0,
      staff: staffCount ?? 0,
      events: eventsCount ?? 0,
      registrations: registrationsCount ?? 0,
      attendanceToday: attendanceCount ?? 0,
      openPolls: pollsCount ?? 0,
      openTickets: ticketsCount ?? 0,
    };
  }

  // ─── Students Operations ───
  async getStudents({ search = '', year = 'All', limit = 100, page = 0 } = {}) {
    let query = this.client.from('students').select('*', { count: 'exact' });

    if (year && year !== 'All') {
      query = query.ilike('year_level', `%${year}%`);
    }

    if (search && search.trim()) {
      const q = search.trim();
      query = query.or(`roll_no.ilike.%${q}%,name.ilike.%${q}%`);
    }

    const from = page * limit;
    const to = from + limit - 1;
    const { data, count, error } = await query
      .order('roll_no', { ascending: true })
      .range(from, to);

    if (error) throw error;

    const enriched = (data || []).map((s) => ({
      ...s,
      email: `${s.roll_no.toLowerCase()}@sasi.ac.in`,
    }));

    return { students: enriched, total: count || 0 };
  }

  async addStudent(student) {
    const userId = student.user_id || `u_${student.roll_no.toLowerCase()}`;
    await this.client.from('users').upsert({
      id: userId,
      username: student.roll_no,
      email: student.email || `${student.roll_no.toLowerCase()}@sasi.ac.in`,
      role: 'STUDENT',
      department: student.department || 'Information Technology',
      status: student.status || 'ACTIVE',
    });

    const { data, error } = await this.client.from('students').upsert({
      user_id: userId,
      roll_no: student.roll_no,
      name: student.name,
      department: student.department || 'Information Technology',
      year_level: student.year_level || '3rd Year',
      section: student.section || 'B',
      academic_year_id: null,
      qr_token: student.qr_token || `ELITE_QR_${student.roll_no}`,
      status: student.status || 'ACTIVE',
      updated_at: new Date().toISOString(),
    });

    if (error) throw error;
    return data;
  }

  async updateStudent(rollNo, updates) {
    const cleanUpdates = { ...updates };
    delete cleanUpdates.email; // email is stored in users table

    const { data, error } = await this.client
      .from('students')
      .update({ ...cleanUpdates, updated_at: new Date().toISOString() })
      .eq('roll_no', rollNo);

    if (error) throw error;

    if (updates.email || updates.name || updates.status) {
      const userId = `u_${rollNo.toLowerCase()}`;
      try {
        await this.client.from('users').update({
          email: updates.email,
          status: updates.status,
        }).eq('id', userId);
      } catch (err) {
        console.warn('Could not sync user status:', err);
      }
    }

    return data;
  }

  async deleteStudent(rollNo) {
    const userId = `u_${rollNo.toLowerCase()}`;
    await this.client.from('students').delete().eq('roll_no', rollNo);
    await this.client.from('users').delete().eq('id', userId);
    return true;
  }

  // ─── Staff Operations ───
  async getStaff() {
    const { data, error } = await this.client.from('staff').select('*').order('employee_id', { ascending: true });
    if (error) throw error;
    return (data || []).map((st) => ({
      ...st,
      email: `${st.employee_id.toLowerCase()}@sasi.ac.in`,
    }));
  }

  async addStaff(staffMember) {
    const userId = staffMember.user_id || `u_${staffMember.employee_id.toLowerCase()}`;
    await this.client.from('users').upsert({
      id: userId,
      username: staffMember.employee_id,
      email: staffMember.email || `${staffMember.employee_id.toLowerCase()}@sasi.ac.in`,
      role: 'STAFF',
      department: staffMember.department || 'Information Technology',
    });

    const { data, error } = await this.client.from('staff').upsert({
      user_id: userId,
      employee_id: staffMember.employee_id,
      name: staffMember.name,
      designation: staffMember.designation || 'Assistant Professor',
      department: staffMember.department || 'Information Technology',
      phone: staffMember.phone,
      cabin: staffMember.cabin || 'IT Staff Room A',
      username: staffMember.employee_id,
    });

    if (error) throw error;
    return data;
  }

  async updateStaff(employeeId, updates) {
    const cleanUpdates = { ...updates };
    delete cleanUpdates.email;

    const { data, error } = await this.client
      .from('staff')
      .update(cleanUpdates)
      .eq('employee_id', employeeId);

    if (error) throw error;
    return data;
  }

  async deleteStaff(employeeId) {
    const userId = `u_${employeeId.toLowerCase()}`;
    await this.client.from('staff').delete().eq('employee_id', employeeId);
    await this.client.from('users').delete().eq('id', userId);
    return true;
  }

  // ─── Events Operations ───
  async getEvents() {
    const { data, error } = await this.client
      .from('events')
      .select('*, event_registrations(count)')
      .order('event_date', { ascending: true });
    if (error) throw error;
    return (data || []).map((ev) => {
      const liveCount =
        ev.event_registrations?.[0]?.count ?? ev.registered_count ?? 0;
      return {
        ...ev,
        registered_count: liveCount,
      };
    });
  }

  async createEvent(event) {
    const id = event.id || `ev_${Date.now()}`;
    const { data, error } = await this.client.from('events').insert({
      id,
      title: event.title,
      description: event.description || '',
      banner_url: event.banner_url || null,
      event_date: event.event_date || new Date().toISOString().split('T')[0],
      start_time: event.start_time || '10:00 AM',
      end_time: event.end_time || '04:00 PM',
      max_capacity: parseInt(event.max_capacity) || 100,
      registered_count: 0,
      venue: event.venue || 'Campus Auditorium',
      event_type: event.event_type || 'Technical',
      eligible_years: event.eligible_years || 'All',
      status: event.status || 'OPEN',
      faculty_coordinators: event.faculty_coordinators || 'IT Department Faculty',
      student_coordinators: event.student_coordinators || '',
      rules: typeof event.rules === 'string' ? event.rules : JSON.stringify(event.rules || []),
      participation_type: event.participation_type || 'Individual',
      created_at: new Date().toISOString(),
    });

    if (error) throw error;
    return data;
  }

  async updateEvent(id, updates) {
    const { data, error } = await this.client.from('events').update(updates).eq('id', id);
    if (error) throw error;
    return data;
  }

  async deleteEvent(id) {
    const { error } = await this.client.from('events').delete().eq('id', id);
    if (error) throw error;
    return true;
  }

  async getEventRegistrations(eventId) {
    const { data, error } = await this.client
      .from('event_registrations')
      .select('*')
      .eq('event_id', eventId)
      .order('registered_at', { ascending: false });
    if (error) throw error;
    return data || [];
  }

  // ─── Project Submissions Operations ───
  async getProjectSubmissions(eventId) {
    let query = this.client.from('project_submissions').select('*').order('created_at', { ascending: false });
    if (eventId) {
      query = query.eq('event_id', eventId);
    }
    const { data, error } = await query;
    if (error) throw error;
    return data || [];
  }

  async updateProjectSubmissionStatus(id, status) {
    const { data, error } = await this.client
      .from('project_submissions')
      .update({ status, updated_at: new Date().toISOString() })
      .eq('id', id);
    if (error) throw error;
    return data;
  }

  async getProjectVotingResults(eventId) {
    const { data: projects, error } = await this.client
      .from('project_submissions')
      .select('id, team_name, leader_name, project_name, vote_count, status')
      .eq('event_id', eventId)
      .order('vote_count', { ascending: false });

    if (error) throw error;

    const totalVotes = (projects || []).reduce((acc, p) => acc + (p.vote_count || 0), 0);
    return {
      projects: projects || [],
      totalVotes,
    };
  }

  // ─── Storage Operations ───
  async uploadPollImage(file) {
    const fileExt = file.name ? file.name.split('.').pop() : 'png';
    const filePath = `poll_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.${fileExt}`;
    const { error } = await this.client.storage.from('poll_images').upload(filePath, file, {
      cacheControl: '3600',
      upsert: true,
    });
    if (error) throw error;

    const { data: publicUrlData } = this.client.storage.from('poll_images').getPublicUrl(filePath);
    return publicUrlData.publicUrl;
  }

  async uploadProjectImage(file) {
    const fileExt = file.name ? file.name.split('.').pop() : 'png';
    const filePath = `proj_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.${fileExt}`;
    const { error } = await this.client.storage.from('project_assets').upload(filePath, file, {
      cacheControl: '3600',
      upsert: true,
    });
    if (error) throw error;

    const { data: publicUrlData } = this.client.storage.from('project_assets').getPublicUrl(filePath);
    return publicUrlData.publicUrl;
  }

  // ─── Supabase Realtime Subscriptions ───
  subscribeToEvents(onPayload) {
    try {
      const channelId = `admin_events_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const channel = this.client
        .channel(channelId)
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'events' },
          (payload) => onPayload(payload)
        )
        .subscribe();
      return () => {
        try {
          this.client.removeChannel(channel);
        } catch (e) {}
      };
    } catch (err) {
      console.warn('Realtime subscribeToEvents failed:', err);
      return () => {};
    }
  }

  subscribeToRegistrations(onPayload) {
    try {
      const channelId = `admin_regs_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const channel = this.client
        .channel(channelId)
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'event_registrations' },
          (payload) => onPayload(payload)
        )
        .subscribe();
      return () => {
        try {
          this.client.removeChannel(channel);
        } catch (e) {}
      };
    } catch (err) {
      console.warn('Realtime subscribeToRegistrations failed:', err);
      return () => {};
    }
  }

  subscribeToProjectSubmissions(eventId, onPayload) {
    try {
      const channelId = `admin_proj_sub_${eventId || 'all'}_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const filter = eventId ? `event_id=eq.${eventId}` : undefined;
      const channel = this.client
        .channel(channelId)
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'project_submissions', filter },
          (payload) => onPayload(payload)
        )
        .subscribe();
      return () => {
        try {
          this.client.removeChannel(channel);
        } catch (e) {}
      };
    } catch (err) {
      console.warn('Realtime subscribeToProjectSubmissions failed:', err);
      return () => {};
    }
  }

  subscribeToProjectVotes(eventId, onPayload) {
    try {
      const channelId = `admin_proj_votes_${eventId || 'all'}_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const filter = eventId ? `event_id=eq.${eventId}` : undefined;
      const channel = this.client
        .channel(channelId)
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'project_votes', filter },
          (payload) => onPayload(payload)
        )
        .subscribe();
      return () => {
        try {
          this.client.removeChannel(channel);
        } catch (e) {}
      };
    } catch (err) {
      console.warn('Realtime subscribeToProjectVotes failed:', err);
      return () => {};
    }
  }

  subscribeToPollVotes(onPayload) {
    try {
      const channelId = `admin_poll_opts_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const channel = this.client
        .channel(channelId)
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'poll_options' },
          (payload) => onPayload(payload)
        )
        .subscribe();
      return () => {
        try {
          this.client.removeChannel(channel);
        } catch (e) {}
      };
    } catch (err) {
      console.warn('Realtime subscribeToPollVotes failed:', err);
      return () => {};
    }
  }

  // ─── Turnstile Attendance Operations ───
  async getAttendanceLogs({ limit = 50 } = {}) {
    const { data, error } = await this.client
      .from('event_attendance')
      .select('*')
      .order('scanned_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return data || [];
  }

  async logAttendance({ studentRoll, studentName, eventId, room = 'Turnstile Gate #2', status = 'PRESENT' }) {
    const id = `ATT-${Date.now()}`;
    const cleanRoll = studentRoll.toUpperCase().trim();
    const studentId = `u_${cleanRoll.toLowerCase()}`;
    const studentEmail = `${cleanRoll.toLowerCase()}@sasi.ac.in`;

    const { data, error } = await this.client.from('event_attendance').insert({
      id,
      event_id: eventId || 'ev_vibe_coding',
      student_id: studentId,
      student_roll: cleanRoll,
      student_name: studentName || 'Student Access',
      student_email: studentEmail,
      scanned_by: room,
      scanned_by_name: 'Admin Console',
      status: status.toUpperCase(),
      session: room,
      scanned_at: new Date().toISOString(),
    }).select();

    if (error) throw error;
    return data;
  }

  // ─── Polls & Voting Operations ───
  async getPolls() {
    const { data: polls, error } = await this.client.from('polls').select('*').order('created_at', { ascending: false });
    if (error) throw error;

    const fullPolls = await Promise.all(
      polls.map(async (p) => {
        const { data: options } = await this.client.from('poll_options').select('*').eq('poll_id', p.id);
        return { ...p, options: options || [] };
      })
    );
    return fullPolls;
  }

  async createPoll({ question, description, category = 'Department', options = [] }) {
    const pollId = `poll_${Date.now()}`;
    const { error: pollError } = await this.client.from('polls').insert({
      id: pollId,
      question,
      description,
      category,
      target_years: 'All',
      status: 'OPEN',
      created_at: new Date().toISOString(),
    });

    if (pollError) throw pollError;

    if (options.length > 0) {
      const optionRows = options.map((opt, idx) => {
        if (typeof opt === 'string') {
          return {
            id: `opt_${pollId}_${idx}`,
            poll_id: pollId,
            text: opt,
            description: null,
            image_url: null,
            vote_count: 0,
          };
        }
        return {
          id: `opt_${pollId}_${idx}`,
          poll_id: pollId,
          text: opt.text || `Option ${idx + 1}`,
          description: opt.description || null,
          image_url: opt.imageUrl || opt.image_url || null,
          vote_count: 0,
        };
      });
      await this.client.from('poll_options').insert(optionRows);
    }

    return pollId;
  }

  async updatePollStatus(pollId, status) {
    const { error } = await this.client.from('polls').update({ status }).eq('id', pollId);
    if (error) throw error;
    return true;
  }

  async deletePoll(pollId) {
    await this.client.from('poll_votes').delete().eq('poll_id', pollId);
    await this.client.from('poll_options').delete().eq('poll_id', pollId);
    const { error } = await this.client.from('polls').delete().eq('id', pollId);
    if (error) throw error;
    return true;
  }

  async deleteRegistration(registrationId) {
    const { error } = await this.client.from('event_registrations').delete().eq('id', registrationId);
    if (error) throw error;
    return true;
  }

  async deleteAttendance(attendanceId) {
    const { error } = await this.client.from('event_attendance').delete().eq('id', attendanceId);
    if (error) throw error;
    return true;
  }

  async deleteNotification(notificationId) {
    const { error } = await this.client.from('notifications').delete().eq('id', notificationId);
    if (error) throw error;
    return true;
  }

  // ─── Broadcast Notifications & Alerts ───
  async getNotifications({ limit = 30 } = {}) {
    const { data, error } = await this.client
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return data || [];
  }

  async broadcastNotification({ title, message, category = 'Urgent', target_audience = 'ALL' }) {
    const id = `NOTIF-${Date.now()}`;
    const { data, error } = await this.client.from('notifications').insert({
      id,
      title,
      message,
      category,
      target_audience,
      created_at: new Date().toISOString(),
    });

    if (error) throw error;
    return data;
  }

  // ─── Student Queries / Tickets ───
  async getTickets() {
    const { data, error } = await this.client
      .from('student_queries')
      .select('*')
      .order('created_at', { ascending: false });
    if (error) throw error;
    return data || [];
  }

  async updateTicketStatus(id, status, mentor = null) {
    const updates = { status };
    if (mentor) updates.mentor = mentor;

    const { data, error } = await this.client.from('student_queries').update(updates).eq('id', id);
    if (error) throw error;
    return data;
  }

  // ─── Direct Database Management & Dynamic Table Operations ───
  getTableDefinitions() {
    return [
      { name: 'events', pk: 'id', label: 'Events', desc: 'Department technical & cultural events' },
      { name: 'students', pk: 'user_id', altPk: 'roll_no', label: 'Students', desc: 'Enrolled student academic profiles' },
      { name: 'users', pk: 'id', label: 'Users', desc: 'Authentication & core user credentials' },
      { name: 'profiles', pk: 'id', label: 'Profiles', desc: 'Consolidated user profiles for mobile' },
      { name: 'staff', pk: 'user_id', altPk: 'employee_id', label: 'Faculty & Staff', desc: 'Department professors and mentors' },
      { name: 'event_registrations', pk: 'id', label: 'Registrations', desc: 'Individual & team event registrations' },
      { name: 'event_attendance', pk: 'id', label: 'Attendance Logs', desc: 'Turnstile & session check-in logs' },
      { name: 'project_submissions', pk: 'id', label: 'Project Submissions', desc: 'Hackathon & competition submissions' },
      { name: 'project_votes', pk: 'id', label: 'Project Votes', desc: 'Peer & faculty showcase votes' },
      { name: 'polls', pk: 'id', label: 'Polls', desc: 'Campus opinion polls & surveys' },
      { name: 'poll_options', pk: 'id', label: 'Poll Options', desc: 'Choices for active polls' },
      { name: 'poll_votes', pk: 'id', label: 'Poll Votes', desc: 'Student votes recorded per option' },
      { name: 'notifications', pk: 'id', label: 'Notifications', desc: 'System alerts and push notifications' },
      { name: 'notification_reads', pk: 'id', label: 'Notification Reads', desc: 'Read receipts for notifications' },
      { name: 'student_queries', pk: 'id', label: 'Student Queries', desc: 'Grievances, mentorship & help tickets' },
      { name: 'academic_years', pk: 'id', label: 'Academic Years', desc: 'College academic sessions' },
      { name: 'alerts', pk: 'id', label: 'Urgent Alerts', desc: 'High-priority banner alerts' },
      { name: 'announcements', pk: 'id', label: 'Announcements', desc: 'Campus news bulletins' },
      { name: 'audit_logs', pk: 'id', label: 'Audit Logs', desc: 'System mutation audit trails' },
      { name: 'event_staff', pk: 'id', label: 'Event Coordinators', desc: 'Faculty assigned to oversee events' },
      { name: 'fcm_tokens', pk: 'token', label: 'FCM Push Tokens', desc: 'Device tokens for Firebase messaging' },
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

