import React, { useState, useEffect } from 'react';
import { Download, Plus } from 'lucide-react';
import supabaseAdmin from '../services/supabase';
import Modal from '../components/Modal';

export default function AttendanceView({ isCheckInOpen, setIsCheckInOpen }) {
  const [logs, setLogs] = useState([]);
  const [isLoading, setIsLoading] = useState(false);

  // Manual Check-In Form
  const [checkInRoll, setCheckInRoll] = useState('');
  const [checkInName, setCheckInName] = useState('');
  const [checkInEvent, setCheckInEvent] = useState('Campus Gate / Event Check-in');
  const [checkInStatus, setCheckInStatus] = useState('PRESENT');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchLogs = async () => {
    setIsLoading(true);
    try {
      const data = await supabaseAdmin.getAttendanceLogs({ limit: 100 });
      setLogs(data);
    } catch (e) {
      console.error('Error fetching attendance logs:', e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs();
  }, []);

  const handleManualCheckIn = async (e) => {
    e.preventDefault();
    if (!checkInRoll.trim()) return;

    setIsSubmitting(true);
    try {
      await supabaseAdmin.logAttendance({
        studentRoll: checkInRoll.trim(),
        studentName: checkInName.trim() || 'Student Verified',
        room: checkInEvent.trim(),
        status: checkInStatus,
      });
      setIsCheckInOpen(false);
      setCheckInRoll('');
      setCheckInName('');
      fetchLogs();
    } catch (err) {
      alert('Error logging attendance: ' + err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const exportAttendanceCSV = () => {
    if (logs.length === 0) return;
    const headers = ['Student Name', 'Student ID (Roll No)', 'Event / Location', 'Date & Time', 'Status'];
    const rows = logs.map((l) => [
      `"${l.student_name || ''}"`,
      `"${l.student_roll || ''}"`,
      `"${l.room || l.scanned_by || 'Main Check-in'}"`,
      `"${l.scanned_at || ''}"`,
      `"${l.status || 'PRESENT'}"`,
    ]);
    const csv = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const link = document.createElement('a');
    link.href = encodeURI(csv);
    link.download = `attendance_report_${Date.now()}.csv`;
    link.click();
  };

  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h2>Attendance</h2>
          <p>Student check-ins and attendance records</p>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <button onClick={exportAttendanceCSV} className="btn btn-secondary">
            <Download size={14} />
            <span>Export CSV</span>
          </button>
          <button onClick={() => setIsCheckInOpen(true)} className="btn btn-primary">
            <Plus size={14} />
            <span>Record Check-In</span>
          </button>
        </div>
      </div>

      {logs.length === 0 && !isLoading ? (
        <div className="empty-state">No attendance records found</div>
      ) : (
        <div className="table-wrapper">
          <table className="simple-table">
            <thead>
              <tr>
                <th>Student</th>
                <th>ID</th>
                <th>Event</th>
                <th>Date</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((l) => (
                <tr key={l.id}>
                  <td style={{ fontWeight: 600 }}>{l.student_name || 'Student'}</td>
                  <td><code>{l.student_roll}</code></td>
                  <td>{l.room || l.scanned_by || 'Campus Gate'}</td>
                  <td style={{ color: 'var(--text-muted)' }}>
                    {l.scanned_at ? new Date(l.scanned_at).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }) : '-'}
                  </td>
                  <td>
                    <span className="badge badge-success">{l.status || 'PRESENT'}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Manual Check-In Modal */}
      <Modal
        isOpen={isCheckInOpen}
        onClose={() => setIsCheckInOpen(false)}
        title="Record Student Attendance"
      >
        <form onSubmit={handleManualCheckIn}>
          <div className="form-group">
            <label>Student Roll Number *</label>
            <input
              type="text"
              className="form-control"
              placeholder="e.g. 23K61A1201"
              value={checkInRoll}
              onChange={(e) => setCheckInRoll(e.target.value.toUpperCase())}
              required
            />
          </div>

          <div className="form-group">
            <label>Student Name</label>
            <input
              type="text"
              className="form-control"
              placeholder="e.g. Rahul Sharma"
              value={checkInName}
              onChange={(e) => setCheckInName(e.target.value)}
            />
          </div>

          <div className="form-group">
            <label>Event / Location</label>
            <input
              type="text"
              className="form-control"
              placeholder="e.g. Tech Quiz 2026, Lab 402"
              value={checkInEvent}
              onChange={(e) => setCheckInEvent(e.target.value)}
            />
          </div>

          <div className="form-group">
            <label>Status</label>
            <select
              className="form-control"
              value={checkInStatus}
              onChange={(e) => setCheckInStatus(e.target.value)}
            >
              <option value="PRESENT">PRESENT</option>
              <option value="LATE">LATE</option>
              <option value="EXCUSED">EXCUSED</option>
            </select>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '16px' }}>
            <button type="button" onClick={() => setIsCheckInOpen(false)} className="btn btn-secondary">
              Cancel
            </button>
            <button type="submit" disabled={isSubmitting} className="btn btn-primary">
              {isSubmitting ? 'Recording...' : 'Confirm Check-In'}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
