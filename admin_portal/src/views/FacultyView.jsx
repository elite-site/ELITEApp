import React, { useState, useEffect } from 'react';
import { Plus, Search, Mail, Phone, MapPin, Briefcase, UserCheck } from 'lucide-react';
import supabaseAdmin from '../services/supabase';
import Modal from '../components/Modal';

export default function FacultyView() {
  const [faculty, setFaculty] = useState([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isAddOpen, setIsAddOpen] = useState(false);

  const [formData, setFormData] = useState({
    employee_id: '',
    name: '',
    designation: 'Assistant Professor',
    department: 'Information Technology',
    email: '',
    phone: '',
    cabin: 'IT Staff Room A',
  });

  const fetchFaculty = async () => {
    setIsLoading(true);
    try {
      const data = await supabaseAdmin.getStaff();
      setFaculty(data);
    } catch (e) {
      console.error(e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchFaculty();
  }, []);

  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.employee_id || !formData.name) return;

    try {
      await supabaseAdmin.addStaff(formData);
      setIsAddOpen(false);
      setFormData({
        employee_id: '',
        name: '',
        designation: 'Assistant Professor',
        department: 'Information Technology',
        email: '',
        phone: '',
        cabin: 'IT Staff Room A',
      });
      fetchFaculty();
    } catch (err) {
      alert('Error saving faculty: ' + err.message);
    }
  };

  const filtered = faculty.filter(
    (f) =>
      f.name?.toLowerCase().includes(search.toLowerCase()) ||
      f.employee_id?.toLowerCase().includes(search.toLowerCase()) ||
      f.designation?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="page-container">
      {/* Toolbar */}
      <div className="toolbar">
        <div className="search-box">
          <Search size={16} className="search-icon" />
          <input
            type="text"
            placeholder="Search faculty by name, employee ID, designation..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        <button onClick={() => setIsAddOpen(true)} className="btn btn-primary">
          <Plus size={15} />
          <span>Add Faculty Member</span>
        </button>
      </div>

      {/* Faculty Cards Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '16px' }}>
        {filtered.map((member) => (
          <div key={member.employee_id} className="card" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <div
                style={{
                  width: '40px',
                  height: '40px',
                  borderRadius: '6px',
                  background: 'var(--primary-subtle)',
                  border: '1px solid var(--border-color)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontWeight: '700',
                  fontSize: '15px',
                  color: 'var(--primary)',
                }}
              >
                {member.name ? member.name.charAt(0) : 'F'}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <h4 style={{ fontWeight: '600', fontSize: '14px', color: 'var(--text-main)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {member.name}
                </h4>
                <div style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <Briefcase size={12} /> {member.designation || 'Faculty Coordinator'}
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', borderTop: '1px solid var(--border-color)', paddingTop: '10px', fontSize: '12px', color: 'var(--text-muted)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span className="badge badge-info">{member.employee_id}</span>
                <span>{member.department || 'Information Technology'}</span>
              </div>
              {member.email && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Mail size={13} style={{ color: 'var(--text-muted)' }} />
                  <span>{member.email}</span>
                </div>
              )}
              {member.cabin && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <MapPin size={13} style={{ color: 'var(--text-muted)' }} />
                  <span>{member.cabin}</span>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Add Faculty Modal */}
      <Modal
        isOpen={isAddOpen}
        onClose={() => setIsAddOpen(false)}
        title="Register Faculty Member"
        footer={
          <>
            <button onClick={() => setIsAddOpen(false)} className="btn btn-secondary">
              Cancel
            </button>
            <button onClick={handleSave} className="btn btn-primary">
              Register Staff
            </button>
          </>
        }
      >
        <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div className="form-row">
            <div className="form-group">
              <label>Employee ID *</label>
              <input
                type="text"
                className="form-control"
                placeholder="e.g. EMP_IT_101"
                value={formData.employee_id}
                onChange={(e) => setFormData({ ...formData, employee_id: e.target.value.toUpperCase() })}
                required
              />
            </div>
            <div className="form-group">
              <label>Full Name *</label>
              <input
                type="text"
                className="form-control"
                placeholder="e.g. Dr. AVN Chandra Sekhar"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                required
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label>Designation</label>
              <input
                type="text"
                className="form-control"
                placeholder="e.g. Professor & HOD"
                value={formData.designation}
                onChange={(e) => setFormData({ ...formData, designation: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label>Cabin / Office Location</label>
              <input
                type="text"
                className="form-control"
                placeholder="e.g. IT Department HOD Cabin"
                value={formData.cabin}
                onChange={(e) => setFormData({ ...formData, cabin: e.target.value })}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label>Official Email</label>
              <input
                type="email"
                className="form-control"
                placeholder="e.g. hod_it@sasi.ac.in"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label>Contact Phone</label>
              <input
                type="text"
                className="form-control"
                placeholder="+91 98765 43210"
                value={formData.phone}
                onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
              />
            </div>
          </div>
        </form>
      </Modal>
    </div>
  );
}
