import React, { useState, useEffect } from 'react';
import {
  Search,
  Plus,
  Download,
  QrCode,
  Edit2,
  Trash2,
  CheckCircle2,
  XCircle,
  GraduationCap,
  Filter,
} from 'lucide-react';
import supabaseAdmin from '../services/supabase';
import Modal from '../components/Modal';

export default function StudentsView() {
  const [students, setStudents] = useState([]);
  const [totalCount, setTotalCount] = useState(0);
  const [search, setSearch] = useState('');
  const [yearFilter, setYearFilter] = useState('All');
  const [page, setPage] = useState(0);
  const [isLoading, setIsLoading] = useState(false);

  // Modals state
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [isQrOpen, setIsQrOpen] = useState(false);
  const [selectedStudent, setSelectedStudent] = useState(null);

  // New Student Form
  const [formData, setFormData] = useState({
    roll_no: '',
    name: '',
    email: '',
    department: 'Information Technology',
    year_level: '3rd Year',
    section: 'B',
    status: 'ACTIVE',
  });

  const fetchStudents = async () => {
    setIsLoading(true);
    try {
      const { students: data, total } = await supabaseAdmin.getStudents({
        search,
        year: yearFilter,
        page,
        limit: 50,
      });
      setStudents(data);
      setTotalCount(total);
    } catch (e) {
      console.error(e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchStudents();
  }, [search, yearFilter, page]);

  const handleSaveStudent = async (e) => {
    e.preventDefault();
    if (!formData.roll_no || !formData.name) return;

    try {
      await supabaseAdmin.addStudent(formData);
      setIsAddOpen(false);
      setFormData({
        roll_no: '',
        name: '',
        email: '',
        department: 'Information Technology',
        year_level: '3rd Year',
        section: 'B',
        status: 'ACTIVE',
      });
      fetchStudents();
    } catch (err) {
      alert('Error creating student: ' + err.message);
    }
  };

  const handleToggleStatus = async (student) => {
    const newStatus = student.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    try {
      await supabaseAdmin.updateStudent(student.roll_no, { status: newStatus });
      setStudents((prev) =>
        prev.map((s) => (s.roll_no === student.roll_no ? { ...s, status: newStatus } : s))
      );
    } catch (err) {
      alert('Error updating status: ' + err.message);
    }
  };

  const exportCSV = () => {
    if (students.length === 0) return;
    const headers = ['Roll No', 'Name', 'Email', 'Year Level', 'Section', 'Status', 'QR Token'];
    const rows = students.map((s) => [
      s.roll_no,
      `"${s.name}"`,
      s.email || '',
      `"${s.year_level}"`,
      s.section || 'A',
      s.status || 'ACTIVE',
      s.qr_token || '',
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `elite_students_${yearFilter.toLowerCase()}_${Date.now()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="page-container">
      {/* Top Toolbar */}
      <div className="toolbar">
        <div className="search-box">
          <Search size={16} className="search-icon" />
          <input
            type="text"
            placeholder="Search by Roll No, Student Name, or Email..."
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(0);
            }}
          />
        </div>

        {/* Year Filter Pills */}
        <div className="filter-group">
          {['All', '1st Year', '2nd Year', '3rd Year', '4th Year'].map((yr) => (
            <button
              key={yr}
              className={`filter-btn ${yearFilter === yr ? 'active' : ''}`}
              onClick={() => {
                setYearFilter(yr);
                setPage(0);
              }}
            >
              {yr}
            </button>
          ))}
        </div>

        {/* Actions */}
        <div style={{ display: 'flex', gap: '8px' }}>
          <button onClick={exportCSV} className="btn btn-secondary">
            <Download size={15} />
            <span>Export CSV</span>
          </button>
          <button onClick={() => setIsAddOpen(true)} className="btn btn-primary">
            <Plus size={15} />
            <span>Enroll Student</span>
          </button>
        </div>
      </div>

      {/* Stats Summary Banner */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <p style={{ color: 'var(--text-muted)', fontSize: '13px' }}>
          Displaying <strong style={{ color: 'var(--text-main)' }}>{students.length}</strong> of{' '}
          <strong style={{ color: 'var(--text-main)' }}>{totalCount}</strong> enrolled student accounts
        </p>
        <div style={{ display: 'flex', gap: '8px' }}>
          <button
            className="btn btn-secondary"
            style={{ padding: '4px 10px', fontSize: '12px' }}
            disabled={page === 0}
            onClick={() => setPage((p) => Math.max(0, p - 1))}
          >
            Previous
          </button>
          <button
            className="btn btn-secondary"
            style={{ padding: '4px 10px', fontSize: '12px' }}
            disabled={(page + 1) * 50 >= totalCount}
            onClick={() => setPage((p) => p + 1)}
          >
            Next
          </button>
        </div>
      </div>

      {/* Students Data Table */}
      <div className="table-wrapper">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Roll Number</th>
              <th>Student Name</th>
              <th>Year & Section</th>
              <th>Institutional Email</th>
              <th>Status</th>
              <th>Digital Pass</th>
              <th style={{ textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {students.map((student) => {
              const isActive = student.status === 'ACTIVE';
              return (
                <tr key={student.roll_no}>
                  <td>
                    <span style={{ fontFamily: 'var(--font-mono)', fontWeight: '600', color: 'var(--text-main)' }}>
                      {student.roll_no}
                    </span>
                  </td>
                  <td>
                    <div style={{ fontWeight: '600' }}>{student.name}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      {student.department || 'Information Technology'}
                    </div>
                  </td>
                  <td>
                    <span className="badge badge-info">
                      {student.year_level} • Sec {student.section || 'B'}
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-muted)' }}>{student.email || '—'}</td>
                  <td>
                    <button
                      onClick={() => handleToggleStatus(student)}
                      className={`badge ${isActive ? 'badge-success' : 'badge-danger'}`}
                      style={{ border: 'none', cursor: 'pointer', padding: '4px 10px' }}
                      title="Click to toggle active/inactive"
                    >
                      {isActive ? <CheckCircle2 size={11} /> : <XCircle size={11} />}
                      {student.status || 'ACTIVE'}
                    </button>
                  </td>
                  <td>
                    <button
                      onClick={() => {
                        setSelectedStudent(student);
                        setIsQrOpen(true);
                      }}
                      className="btn-icon"
                      style={{ width: '32px', height: '32px' }}
                      title="View Digital Pass QR"
                    >
                      <QrCode size={16} />
                    </button>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <div style={{ display: 'inline-flex', gap: '6px' }}>
                      <button
                        onClick={() => {
                          setFormData({
                            roll_no: student.roll_no,
                            name: student.name,
                            email: student.email || '',
                            department: student.department || 'Information Technology',
                            year_level: student.year_level || '3rd Year',
                            section: student.section || 'B',
                            status: student.status || 'ACTIVE',
                          });
                          setIsAddOpen(true);
                        }}
                        className="btn-icon"
                        style={{ width: '32px', height: '32px' }}
                        title="Edit Student"
                      >
                        <Edit2 size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
            {students.length === 0 && !isLoading && (
              <tr>
                <td colSpan={7} style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                  No students found matching the query.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Add / Edit Student Modal */}
      <Modal
        isOpen={isAddOpen}
        onClose={() => setIsAddOpen(false)}
        title={formData.roll_no ? 'Update Student Record' : 'Enroll New Student'}
        footer={
          <>
            <button onClick={() => setIsAddOpen(false)} className="btn btn-secondary">
              Cancel
            </button>
            <button onClick={handleSaveStudent} className="btn btn-primary">
              Save Student
            </button>
          </>
        }
      >
        <form onSubmit={handleSaveStudent} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div className="form-row">
            <div className="form-group">
              <label>Roll Number *</label>
              <input
                type="text"
                className="form-control"
                placeholder="e.g. 23IT001"
                value={formData.roll_no}
                onChange={(e) => setFormData({ ...formData, roll_no: e.target.value.toUpperCase() })}
                required
              />
            </div>
            <div className="form-group">
              <label>Full Name *</label>
              <input
                type="text"
                className="form-control"
                placeholder="e.g. Rahul Sharma"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                required
              />
            </div>
          </div>

          <div className="form-group">
            <label>Institutional Email</label>
            <input
              type="email"
              className="form-control"
              placeholder="e.g. 23it001@sasi.ac.in"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
            />
          </div>

          <div className="form-row">
            <div className="form-group">
              <label>Academic Year Level</label>
              <select
                className="form-control"
                value={formData.year_level}
                onChange={(e) => setFormData({ ...formData, year_level: e.target.value })}
              >
                <option value="1st Year">1st Year</option>
                <option value="2nd Year">2nd Year</option>
                <option value="3rd Year">3rd Year</option>
                <option value="4th Year">4th Year</option>
              </select>
            </div>
            <div className="form-group">
              <label>Section</label>
              <input
                type="text"
                className="form-control"
                placeholder="A / B / C"
                value={formData.section}
                onChange={(e) => setFormData({ ...formData, section: e.target.value })}
              />
            </div>
          </div>
        </form>
      </Modal>

      {/* QR Code Pass Preview Modal */}
      <Modal
        isOpen={isQrOpen}
        onClose={() => setIsQrOpen(false)}
        title="Student Digital Turnstile Pass"
        footer={
          <button onClick={() => setIsQrOpen(false)} className="btn btn-primary">
            Close Pass
          </button>
        }
      >
        {selectedStudent && (
          <div style={{ textAlign: 'center', padding: '10px 0' }}>
            <div
              style={{
                width: '160px',
                height: '160px',
                margin: '0 auto 16px',
                background: '#ffffff',
                borderRadius: '12px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                padding: '12px',
                border: '1px solid var(--border-color)',
              }}
            >
              {/* QR representation */}
              <div style={{ textAlign: 'center', color: '#0f172a' }}>
                <QrCode size={110} color="#0f172a" />
                <div style={{ fontSize: '9px', fontWeight: '800', marginTop: '4px', letterSpacing: '1px' }}>
                  {selectedStudent.roll_no}
                </div>
              </div>
            </div>

            <h3 style={{ fontSize: '18px', fontWeight: '700', color: 'var(--text-main)' }}>
              {selectedStudent.name}
            </h3>
            <p style={{ color: 'var(--primary)', fontFamily: 'var(--font-mono)', fontWeight: '600', fontSize: '13px' }}>
              {selectedStudent.roll_no} • {selectedStudent.year_level}
            </p>
            <div
              style={{
                margin: '16px auto 0',
                padding: '8px 16px',
                background: 'var(--bg-main)',
                borderRadius: '6px',
                border: '1px solid var(--border-color)',
                display: 'inline-block',
                fontSize: '12px',
                color: 'var(--text-muted)',
              }}
            >
              Hardware Turnstile Token: <strong style={{ color: 'var(--text-main)' }}>{selectedStudent.qr_token}</strong>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
