import React from 'react';

export default function DashboardView({
  metrics = {},
  events = [],
  recentAttendance = [],
  onNavigate,
}) {
  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h2>Dashboard</h2>
          <p>College Administration Overview</p>
        </div>
      </div>

      {/* 5 Simple Bordered Metric Boxes */}
      <div className="stat-boxes-grid">
        <div className="stat-box">
          <div className="stat-box-label">Students</div>
          <div className="stat-box-value">{metrics.students ?? 0}</div>
        </div>

        <div className="stat-box">
          <div className="stat-box-label">Staff</div>
          <div className="stat-box-value">{metrics.staff ?? 0}</div>
        </div>

        <div className="stat-box">
          <div className="stat-box-label">Events</div>
          <div className="stat-box-value">{metrics.events ?? 0}</div>
        </div>

        <div className="stat-box highlight">
          <div className="stat-box-label">Registrations</div>
          <div className="stat-box-value">{metrics.registrations ?? 0}</div>
        </div>

        <div className="stat-box">
          <div className="stat-box-label">Active Polls</div>
          <div className="stat-box-value">{metrics.openPolls ?? 0}</div>
        </div>
      </div>

      {/* Events Summary */}
      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
          <h3 style={{ fontSize: '15px', fontWeight: '700' }}>Events Overview</h3>
          <button onClick={() => onNavigate('events')} className="btn btn-secondary btn-sm">
            View All Events
          </button>
        </div>

        {events.length === 0 ? (
          <div className="empty-state">No events found</div>
        ) : (
          <div className="table-wrapper">
            <table className="simple-table">
              <thead>
                <tr>
                  <th>Event</th>
                  <th>Date</th>
                  <th>Type</th>
                  <th>Registrations</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {events.slice(0, 5).map((ev) => (
                  <tr key={ev.id}>
                    <td style={{ fontWeight: 600 }}>{ev.title}</td>
                    <td>{ev.event_date || 'TBD'}</td>
                    <td>{ev.participation_type || 'Individual'}</td>
                    <td>
                      {ev.registered_count ?? 0} / {ev.max_capacity}
                    </td>
                    <td>
                      <span className={`badge ${ev.status === 'UPCOMING' || ev.status === 'ONGOING' ? 'badge-open' : 'badge-neutral'}`}>
                        {ev.status || 'Active'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Recent Attendance / Gate Activity */}
      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
          <h3 style={{ fontSize: '15px', fontWeight: '700' }}>Recent Attendance Activity</h3>
          <button onClick={() => onNavigate('attendance')} className="btn btn-secondary btn-sm">
            View All Attendance
          </button>
        </div>

        {recentAttendance.length === 0 ? (
          <div className="empty-state">No attendance records today</div>
        ) : (
          <div className="table-wrapper">
            <table className="simple-table">
              <thead>
                <tr>
                  <th>Student</th>
                  <th>Roll No</th>
                  <th>Location</th>
                  <th>Time</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {recentAttendance.slice(0, 5).map((log) => (
                  <tr key={log.id}>
                    <td style={{ fontWeight: 500 }}>{log.student_name || 'Student'}</td>
                    <td><code>{log.student_roll}</code></td>
                    <td>{log.room || log.scanned_by || 'Main Gate'}</td>
                    <td style={{ color: 'var(--text-muted)' }}>
                      {log.scanned_at ? new Date(log.scanned_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '-'}
                    </td>
                    <td>
                      <span className="badge badge-success">{log.status || 'PRESENT'}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
