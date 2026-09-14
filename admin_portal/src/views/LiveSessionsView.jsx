import React, { useState, useEffect, useMemo } from 'react';
import {
  Radio,
  Search,
  RefreshCw,
  Smartphone,
  Globe,
  GraduationCap,
  Users,
  ShieldCheck,
  Clock,
  Calendar,
  CheckCircle2,
  Wifi,
  Sparkles,
  Filter
} from 'lucide-react';
import supabaseAdmin from '../services/supabase';

export default function LiveSessionsView() {
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('ALL'); // ALL, student, staff, admin
  const [statusFilter, setStatusFilter] = useState('ALL'); // ALL, online, offline
  const [lastSyncedAt, setLastSyncedAt] = useState(new Date());

  const loadSessions = async (showRefresh = false) => {
    if (showRefresh) setIsRefreshing(true);
    try {
      const data = await supabaseAdmin.fetchActiveSessions();
      setSessions(data || []);
      setLastSyncedAt(new Date());
    } catch (err) {
      console.error('Error fetching live sessions:', err);
    } finally {
      setLoading(false);
      if (showRefresh) setIsRefreshing(false);
    }
  };

  useEffect(() => {
    loadSessions();

    // 1. Subscribe to Postgres Realtime changes on public.user_sessions
    const unsubscribe = supabaseAdmin.subscribeToSessions(() => {
      loadSessions();
    });

    // 2. High-frequency polling fallback (every 8 seconds) to re-evaluate 2-min active window
    const interval = setInterval(() => {
      loadSessions();
    }, 8000);

    return () => {
      unsubscribe();
      clearInterval(interval);
    };
  }, []);

  // Compute live statistics
  const metrics = useMemo(() => {
    const total = sessions.length;
    const online = sessions.filter((s) => s.is_live_now).length;
    const studentsOnline = sessions.filter((s) => s.is_live_now && s.role === 'student').length;
    const staffOnline = sessions.filter((s) => s.is_live_now && (s.role === 'staff' || s.role === 'admin')).length;
    const totalStudents = sessions.filter((s) => s.role === 'student').length;
    return { total, online, studentsOnline, staffOnline, totalStudents };
  }, [sessions]);

  // Filter sessions
  const filteredSessions = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();
    return sessions.filter((s) => {
      // Role match
      if (roleFilter !== 'ALL') {
        if (roleFilter === 'staff') {
          if (s.role !== 'staff' && s.role !== 'admin') return false;
        } else if (s.role !== roleFilter) {
          return false;
        }
      }

      // Status match
      if (statusFilter === 'online' && !s.is_live_now) return false;
      if (statusFilter === 'offline' && s.is_live_now) return false;

      // Query match (Name, Roll No, Department, Platform)
      if (query) {
        const name = (s.full_name || '').toLowerCase();
        const roll = (s.roll_number || '').toLowerCase();
        const dept = (s.department || '').toLowerCase();
        const plat = (s.platform || '').toLowerCase();
        if (!name.includes(query) && !roll.includes(query) && !dept.includes(query) && !plat.includes(query)) {
          return false;
        }
      }

      return true;
    });
  }, [sessions, searchQuery, roleFilter, statusFilter]);

  const formatRelativeTime = (dateStr) => {
    if (!dateStr) return 'Unknown';
    const d = new Date(dateStr);
    const diffSec = Math.floor((Date.now() - d.getTime()) / 1000);
    if (diffSec < 10) return 'Just now';
    if (diffSec < 60) return `${diffSec}s ago`;
    const diffMin = Math.floor(diffSec / 60);
    if (diffMin < 60) return `${diffMin}m ago`;
    const diffHours = Math.floor(diffMin / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    return d.toLocaleDateString();
  };

  return (
    <div className="page-container">
      {/* Header & Title */}
      <div className="page-header">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <h2>Live App Sessions</h2>
            <span className="live-pulse-badge">
              <span className="live-pulse-dot"></span>
              {metrics.online} Active Now
            </span>
          </div>
          <p>
            Real-time live presence and active device sessions across Android and Web portal.
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
            Synced: {lastSyncedAt.toLocaleTimeString()}
          </span>
          <button
            className="btn btn-secondary"
            onClick={() => loadSessions(true)}
            disabled={isRefreshing}
            style={{ display: 'flex', alignItems: 'center', gap: 6 }}
          >
            <RefreshCw size={14} className={isRefreshing ? 'spin-icon' : ''} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {/* Metrics Cards Grid */}
      <div className="metrics-grid" style={{ marginBottom: 24 }}>
        {/* Metric 1: Online Now */}
        <div className="metric-card" style={{ borderLeft: '4px solid #10b981', position: 'relative', overflow: 'hidden' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <span className="metric-label" style={{ display: 'flex', alignItems: 'center', gap: 6, color: '#10b981', fontWeight: 600 }}>
                <Wifi size={14} />
                Online Right Now
              </span>
              <h2 className="metric-value" style={{ color: '#10b981', marginTop: 4 }}>
                {metrics.online}
              </h2>
            </div>
            <div style={{
              background: 'rgba(16, 185, 129, 0.12)',
              color: '#10b981',
              padding: 10,
              borderRadius: 12,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Radio size={20} className="pulse-slow" />
            </div>
          </div>
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: 8 }}>
            Active inside app in past 2 minutes
          </p>
        </div>

        {/* Metric 2: Total Logged-in Sessions */}
        <div className="metric-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <span className="metric-label">Logged-in Accounts</span>
              <h2 className="metric-value" style={{ marginTop: 4 }}>{metrics.total}</h2>
            </div>
            <div style={{
              background: 'rgba(99, 102, 241, 0.12)',
              color: '#6366f1',
              padding: 10,
              borderRadius: 12,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Smartphone size={20} />
            </div>
          </div>
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: 8 }}>
            Active persisted user devices
          </p>
        </div>

        {/* Metric 3: Students Online */}
        <div className="metric-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <span className="metric-label">Students Online</span>
              <h2 className="metric-value" style={{ marginTop: 4 }}>{metrics.studentsOnline}</h2>
            </div>
            <div style={{
              background: 'rgba(14, 165, 233, 0.12)',
              color: '#0ea5e9',
              padding: 10,
              borderRadius: 12,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <GraduationCap size={20} />
            </div>
          </div>
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: 8 }}>
            Out of {metrics.totalStudents} logged-in students
          </p>
        </div>

        {/* Metric 4: Faculty / Staff Online */}
        <div className="metric-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <span className="metric-label">Faculty / Staff Online</span>
              <h2 className="metric-value" style={{ marginTop: 4 }}>{metrics.staffOnline}</h2>
            </div>
            <div style={{
              background: 'rgba(245, 158, 11, 0.12)',
              color: '#f59e0b',
              padding: 10,
              borderRadius: 12,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Users size={20} />
            </div>
          </div>
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: 8 }}>
            Department faculty active
          </p>
        </div>
      </div>

      {/* Toolbar: Search and Filter Pills */}
      <div className="table-toolbar" style={{ display: 'flex', flexWrap: 'wrap', gap: 12, alignItems: 'center', justifyContent: 'space-between', background: 'var(--card-bg)', padding: '12px 16px', borderRadius: 12, border: '1px solid var(--border-color)', marginBottom: 20 }}>
        {/* Search */}
        <div className="search-box" style={{ minWidth: 260, maxWidth: 380, flex: 1 }}>
          <Search size={16} className="search-icon" />
          <input
            type="text"
            placeholder="Search by Roll No, Name, or Department..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="search-input"
          />
        </div>

        {/* Filter Pills */}
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
          {/* Status Filter */}
          <div style={{ display: 'flex', background: 'var(--bg-secondary)', padding: 3, borderRadius: 8, border: '1px solid var(--border-color)' }}>
            <button
              className={`pill-btn ${statusFilter === 'ALL' ? 'active' : ''}`}
              onClick={() => setStatusFilter('ALL')}
            >
              All Status
            </button>
            <button
              className={`pill-btn ${statusFilter === 'online' ? 'active' : ''}`}
              onClick={() => setStatusFilter('online')}
              style={{ display: 'flex', alignItems: 'center', gap: 6 }}
            >
              <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#10b981' }}></span>
              Online Now ({metrics.online})
            </button>
            <button
              className={`pill-btn ${statusFilter === 'offline' ? 'active' : ''}`}
              onClick={() => setStatusFilter('offline')}
            >
              Offline
            </button>
          </div>

          {/* Role Filter */}
          <div style={{ display: 'flex', background: 'var(--bg-secondary)', padding: 3, borderRadius: 8, border: '1px solid var(--border-color)' }}>
            <button
              className={`pill-btn ${roleFilter === 'ALL' ? 'active' : ''}`}
              onClick={() => setRoleFilter('ALL')}
            >
              All Roles
            </button>
            <button
              className={`pill-btn ${roleFilter === 'student' ? 'active' : ''}`}
              onClick={() => setRoleFilter('student')}
            >
              Students
            </button>
            <button
              className={`pill-btn ${roleFilter === 'staff' ? 'active' : ''}`}
              onClick={() => setRoleFilter('staff')}
            >
              Staff
            </button>
          </div>
        </div>
      </div>

      {/* Sessions List Table */}
      <div className="table-card" style={{ background: 'var(--card-bg)', borderRadius: 14, border: '1px solid var(--border-color)', overflow: 'hidden' }}>
        {loading ? (
          <div style={{ padding: 48, textAlign: 'center', color: 'var(--text-muted)' }}>
            <RefreshCw size={24} className="spin-icon" style={{ margin: '0 auto 12px' }} />
            <p>Loading real-time active sessions...</p>
          </div>
        ) : filteredSessions.length === 0 ? (
          <div style={{ padding: 48, textAlign: 'center', color: 'var(--text-muted)' }}>
            <Users size={32} style={{ margin: '0 auto 12px', opacity: 0.4 }} />
            <p style={{ fontWeight: 600, fontSize: '1rem' }}>No matching sessions found</p>
            <p style={{ fontSize: '0.85rem' }}>
              {searchQuery ? 'Try clearing your search filters.' : 'Active student or staff sessions will appear here as users log in.'}
            </p>
            {searchQuery && (
              <button
                className="btn btn-secondary"
                onClick={() => { setSearchQuery(''); setRoleFilter('ALL'); setStatusFilter('ALL'); }}
                style={{ marginTop: 16 }}
              >
                Clear Filters
              </button>
            )}
          </div>
        ) : (
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Member / Student</th>
                  <th>Roll No / ID</th>
                  <th>Role</th>
                  <th>Academic Info</th>
                  <th>Platform & Device</th>
                  <th>Status</th>
                  <th>Last Active</th>
                  <th>Session Start</th>
                </tr>
              </thead>
              <tbody>
                {filteredSessions.map((s) => {
                  const isOnline = s.is_live_now;
                  const isStudent = s.role === 'student';
                  const initials = (s.full_name || 'U')
                    .split(' ')
                    .map((n) => n[0])
                    .slice(0, 2)
                    .join('')
                    .toUpperCase();

                  return (
                    <tr key={s.id || s.user_id}>
                      {/* Member / Student */}
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                          <div style={{
                            width: 36,
                            height: 36,
                            borderRadius: '50%',
                            background: isStudent ? 'linear-gradient(135deg, #6366f1, #4f46e5)' : 'linear-gradient(135deg, #f59e0b, #d97706)',
                            color: '#ffffff',
                            fontWeight: 700,
                            fontSize: '0.85rem',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            flexShrink: 0
                          }}>
                            {initials}
                          </div>
                          <div>
                            <div style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--text-primary)' }}>
                              {s.full_name}
                            </div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                              {s.department || 'Information Technology'}
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Roll No / ID */}
                      <td>
                        <span className="badge badge-code" style={{ fontFamily: 'monospace', fontWeight: 600, fontSize: '0.8rem' }}>
                          {s.roll_number || 'N/A'}
                        </span>
                      </td>

                      {/* Role */}
                      <td>
                        <span className={`badge ${isStudent ? 'badge-student' : 'badge-staff'}`} style={{ textTransform: 'capitalize' }}>
                          {s.role}
                        </span>
                      </td>

                      {/* Academic Info */}
                      <td>
                        <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                          {isStudent
                            ? `${s.year ? `${s.year} Year` : 'Student'}${s.section ? ` • Sec ${s.section}` : ''}`
                            : 'Faculty Staff'}
                        </span>
                      </td>

                      {/* Platform & Device */}
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.82rem' }}>
                          {s.platform === 'Android' ? (
                            <Smartphone size={14} style={{ color: '#10b981' }} />
                          ) : (
                            <Globe size={14} style={{ color: '#6366f1' }} />
                          )}
                          <span>{s.platform || 'Android'}</span>
                          {s.device_info && (
                            <span style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>({s.device_info})</span>
                          )}
                        </div>
                      </td>

                      {/* Status */}
                      <td>
                        {isOnline ? (
                          <span className="live-status-chip online">
                            <span className="live-dot green"></span>
                            Online Now
                          </span>
                        ) : (
                          <span className="live-status-chip offline">
                            <span className="live-dot gray"></span>
                            Offline
                          </span>
                        )}
                      </td>

                      {/* Last Active */}
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: '0.82rem', color: isOnline ? '#10b981' : 'var(--text-secondary)' }}>
                          <Clock size={12} />
                          <span>{formatRelativeTime(s.last_active_at)}</span>
                        </div>
                      </td>

                      {/* Session Start */}
                      <td>
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                          {s.login_at ? new Date(s.login_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'Today'}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
