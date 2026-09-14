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
      query = query.or(`roll_no.ilike.%${q}%,name.ilike.%${q}%,email.ilike.%${q}%`);
    }

    const from = page * limit;
    const to = from + limit - 1;
    const { data, count, error } = await query
      .order('roll_no', { ascending: true })
      .range(from, to);

    if (error) throw error;
    return { students: data || [], total: count || 0 };
  }

  async addStudent(student) {

    // 1. Ensure user record exists
    const userId = student.user_id || `u_${student.roll_no.toLowerCase()}`;
    await this.client.from('users').upsert({
      id: userId,
      username: student.roll_no,
      email: student.email,
      role: 'STUDENT',
      department: student.department || 'Information Technology',
      status: student.status || 'ACTIVE',
    });

    // 2. Insert into students table
    const { data, error } = await this.client.from('students').upsert({
      user_id: userId,
      roll_no: student.roll_no,
      name: student.name,
      email: student.email,
      department: student.department || 'Information Technology',
      year_level: student.year_level || '3rd Year',
      section: student.section || 'B',
      academic_year_id: 'AY_2026_27',
      qr_token: student.qr_token || `ELITE_QR_${student.roll_no}`,
      status: student.status || 'ACTIVE',
      updated_at: new Date().toISOString(),
    });

    if (error) throw error;
    return data;
  }

  async updateStudent(rollNo, updates) {
    const { data, error } = await this.client
      .from('students')
      .update({ ...updates, updated_at: new Date().toISOString() })
      .eq('roll_no', rollNo);

    if (error) throw error;
    return data;
  }

  async deleteStudent(rollNo) {
    const { error } = await this.client.from('students').delete().eq('roll_no', rollNo);
    if (error) throw error;
    return true;
  }

  // ─── Staff Operations ───
  async getStaff() {
    const { data, error } = await this.client.from('staff').select('*').order('employee_id', { ascending: true });
    if (error) throw error;
    return data || [];
  }

  async addStaff(staffMember) {
    const userId = staffMember.user_id || `u_${staffMember.employee_id.toLowerCase()}`;
    await this.client.from('users').upsert({
      id: userId,
      username: staffMember.employee_id,
      email: staffMember.email,
      role: 'STAFF',
      department: staffMember.department || 'Information Technology',
    });

    const { data, error } = await this.client.from('staff').upsert({
      user_id: userId,
      employee_id: staffMember.employee_id,
      name: staffMember.name,
      designation: staffMember.designation || 'Assistant Professor',
      department: staffMember.department || 'Information Technology',
      email: staffMember.email,
      phone: staffMember.phone,
      cabin: staffMember.cabin || 'IT Staff Room A',
    });

    if (error) throw error;
    return data;
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
    const channel = this.client
      .channel('admin_events_realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'events' },
        (payload) => onPayload(payload)
      )
      .subscribe();
    return () => {
      this.client.removeChannel(channel);
    };
  }

  subscribeToRegistrations(onPayload) {
    const channel = this.client
      .channel('admin_registrations_realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'event_registrations' },
        (payload) => onPayload(payload)
      )
      .subscribe();
    return () => {
      this.client.removeChannel(channel);
    };
  }

  subscribeToProjectSubmissions(eventId, onPayload) {
    const channelName = eventId ? `admin_proj_sub_${eventId}` : 'admin_proj_sub_all';
    const filter = eventId ? `event_id=eq.${eventId}` : undefined;
    const channel = this.client
      .channel(channelName)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'project_submissions', filter },
        (payload) => onPayload(payload)
      )
      .subscribe();
    return () => {
      this.client.removeChannel(channel);
    };
  }

  subscribeToProjectVotes(eventId, onPayload) {
    const channelName = eventId ? `admin_proj_votes_${eventId}` : 'admin_proj_votes_all';
    const filter = eventId ? `event_id=eq.${eventId}` : undefined;
    const channel = this.client
      .channel(channelName)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'project_votes', filter },
        (payload) => onPayload(payload)
      )
      .subscribe();
    return () => {
      this.client.removeChannel(channel);
    };
  }

  subscribeToPollVotes(onPayload) {
    const channel = this.client
      .channel('admin_poll_options_realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'poll_options' },
        (payload) => onPayload(payload)
      )
      .subscribe();
    return () => {
      this.client.removeChannel(channel);
    };
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
    const { data, error } = await this.client.from('event_attendance').insert({
      id,
      event_id: eventId || 'General Campus Turnstile Access',
      student_roll: studentRoll.toUpperCase().trim(),
      student_name: studentName || 'Student Access',
      scanned_by: room,
      status: status.toUpperCase(),
      session: room,
      scanned_at: new Date().toISOString(),
    });

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
}

export const supabaseAdmin = new SupabaseAdminService();
export default supabaseAdmin;
