import React, { useState } from 'react';
import { Download, FileText, Calendar, Users, BarChart3, CheckSquare } from 'lucide-react';
import supabaseAdmin from '../services/supabase';

export default function ReportsView() {
  const [isDownloading, setIsDownloading] = useState(false);

  // 1. Export Registrations
  const exportRegistrations = async () => {
    setIsDownloading(true);
    try {
      const { data, error } = await supabaseAdmin.client
        .from('event_registrations')
        .select(`
          id,
          event_id,
          user_id,
          status,
          registered_at,
          team_name,
          is_team_registration,
          members,
          events ( title, event_date )
        `)
        .order('registered_at', { ascending: false });

      if (error) throw error;

      const headers = ['Registration ID', 'Event Title', 'Event Date', 'Team / User', 'Type', 'Status', 'Registered At'];
      const rows = (data || []).map((r) => [
        r.id,
        `"${r.events?.title || r.event_id}"`,
        `"${r.events?.event_date || ''}"`,
        `"${r.team_name || r.user_id || ''}"`,
        r.is_team_registration ? 'Team' : 'Individual',
        r.status || 'CONFIRMED',
        `"${r.registered_at || ''}"`,
      ]);

      downloadCSV('event_registrations_report.csv', headers, rows);
    } catch (e) {
      alert('Error exporting registrations: ' + e.message);
    } finally {
      setIsDownloading(false);
    }
  };

  // 2. Export Attendance
  const exportAttendance = async () => {
    setIsDownloading(true);
    try {
      const logs = await supabaseAdmin.getAttendanceLogs({ limit: 1000 });
      const headers = ['Log ID', 'Roll No', 'Student Name', 'Location / Event', 'Status', 'Timestamp'];
      const rows = logs.map((l) => [
        l.id,
        `"${l.student_roll || ''}"`,
        `"${l.student_name || ''}"`,
        `"${l.room || l.scanned_by || ''}"`,
        l.status || 'PRESENT',
        `"${l.scanned_at || ''}"`,
      ]);
      downloadCSV('attendance_report.csv', headers, rows);
    } catch (e) {
      alert('Error exporting attendance: ' + e.message);
    } finally {
      setIsDownloading(false);
    }
  };

  // 3. Export Students Roster
  const exportStudents = async () => {
    setIsDownloading(true);
    try {
      const { students } = await supabaseAdmin.getStudents({ limit: 2000 });
      const headers = ['Roll Number', 'Student Name', 'Department', 'Year Level', 'Section', 'Email', 'Status'];
      const rows = students.map((s) => [
        `"${s.roll_no || ''}"`,
        `"${s.name || ''}"`,
        `"${s.department || ''}"`,
        `"${s.year_level || ''}"`,
        `"${s.section || ''}"`,
        `"${s.email || ''}"`,
        `"${s.status || 'ACTIVE'}"`,
      ]);
      downloadCSV('students_roster_report.csv', headers, rows);
    } catch (e) {
      alert('Error exporting student roster: ' + e.message);
    } finally {
      setIsDownloading(false);
    }
  };

  // 4. Export Poll Results
  const exportPollResults = async () => {
    setIsDownloading(true);
    try {
      const polls = await supabaseAdmin.getPolls();
      const headers = ['Poll ID', 'Question', 'Category', 'Status', 'Option Text', 'Votes'];
      const rows = [];
      polls.forEach((p) => {
        (p.options || []).forEach((opt) => {
          rows.push([
            p.id,
            `"${p.question}"`,
            `"${p.category || ''}"`,
            p.status,
            `"${opt.text || ''}"`,
            opt.votes ?? 0,
          ]);
        });
      });
      downloadCSV('poll_voting_results.csv', headers, rows);
    } catch (e) {
      alert('Error exporting poll results: ' + e.message);
    } finally {
      setIsDownloading(false);
    }
  };

  const downloadCSV = (filename, headers, rows) => {
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const link = document.createElement('a');
    link.href = encodeURI(csvContent);
    link.download = filename;
    link.click();
  };

  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h2>Reports</h2>
          <p>Exportable department records, registrations, attendance, and analytics</p>
        </div>
      </div>

      <div className="table-wrapper">
        <table className="simple-table">
          <thead>
            <tr>
              <th>Report Name</th>
              <th>Description</th>
              <th>Format</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td style={{ fontWeight: 600 }}>Event Registrations Report</td>
              <td>All student individual & team registrations with timestamps and statuses</td>
              <td>CSV</td>
              <td>
                <button
                  onClick={exportRegistrations}
                  disabled={isDownloading}
                  className="btn btn-secondary btn-sm"
                >
                  <Download size={13} /> Download
                </button>
              </td>
            </tr>
            <tr>
              <td style={{ fontWeight: 600 }}>Attendance & Check-in Report</td>
              <td>Complete gate logs, seminar hall entries, and verification records</td>
              <td>CSV</td>
              <td>
                <button
                  onClick={exportAttendance}
                  disabled={isDownloading}
                  className="btn btn-secondary btn-sm"
                >
                  <Download size={13} /> Download
                </button>
              </td>
            </tr>
            <tr>
              <td style={{ fontWeight: 600 }}>Student Directory Roster</td>
              <td>Enrolled students directory filtered by department and academic year</td>
              <td>CSV</td>
              <td>
                <button
                  onClick={exportStudents}
                  disabled={isDownloading}
                  className="btn btn-secondary btn-sm"
                >
                  <Download size={13} /> Download
                </button>
              </td>
            </tr>
            <tr>
              <td style={{ fontWeight: 600 }}>Department Voting & Poll Results</td>
              <td>Vote counts and option breakdown for all active and archived student polls</td>
              <td>CSV</td>
              <td>
                <button
                  onClick={exportPollResults}
                  disabled={isDownloading}
                  className="btn btn-secondary btn-sm"
                >
                  <Download size={13} /> Download
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
}
