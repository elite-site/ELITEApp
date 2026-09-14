import React, { useState, useEffect, useRef } from 'react';
import { Plus, ArrowLeft, ExternalLink, Trash2, Edit } from 'lucide-react';
import supabaseAdmin from '../services/supabase';
import Modal from '../components/Modal';

export default function EventsView({ isCreateOpen, setIsCreateOpen }) {
  const [events, setEvents] = useState([]);
  const [isLoading, setIsLoading] = useState(false);

  // Selected event for "Event Details" view
  const [selectedEvent, setSelectedEvent] = useState(null);
  const [registrations, setRegistrations] = useState([]);
  const [projectSubmissions, setProjectSubmissions] = useState([]);
  const [votingResults, setVotingResults] = useState({ projects: [], totalVotes: 0 });
  const [detailsLoading, setDetailsLoading] = useState(false);

  // View Project Modal
  const [viewingProject, setViewingProject] = useState(null);

  // Create / Edit Event Modal
  const [editingId, setEditingId] = useState(null);
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    event_type: 'Technical',
    venue: 'Campus Auditorium',
    event_date: new Date().toISOString().split('T')[0],
    start_time: '10:00 AM',
    end_time: '04:00 PM',
    max_capacity: 100,
    participation_type: 'Individual',
    min_team_size: 1,
    max_team_size: 1,
    is_project_submission_enabled: false,
    project_submission_deadline: '',
    is_voting_enabled: false,
    voting_start: '',
    voting_end: '',
    voting_eligible_roles: 'STUDENT,STAFF',
  });

  const selectedEventRef = useRef(selectedEvent);
  useEffect(() => {
    selectedEventRef.current = selectedEvent;
  }, [selectedEvent]);

  const fetchEvents = async () => {
    setIsLoading(true);
    try {
      const data = await supabaseAdmin.getEvents();
      setEvents(data);
    } catch (e) {
      console.error('Error fetching events:', e);
    } finally {
      setIsLoading(false);
    }
  };

  const loadEventDetails = async (event) => {
    setSelectedEvent(event);
    setDetailsLoading(true);
    try {
      const [regs, projects, votes] = await Promise.all([
        supabaseAdmin.getEventRegistrations(event.id),
        event.is_project_submission_enabled ? supabaseAdmin.getProjectSubmissions(event.id) : Promise.resolve([]),
        event.is_voting_enabled ? supabaseAdmin.getProjectVotingResults(event.id) : Promise.resolve({ projects: [], totalVotes: 0 }),
      ]);
      setRegistrations(regs);
      setProjectSubmissions(projects);
      setVotingResults(votes);
    } catch (e) {
      console.error('Error loading event details:', e);
    } finally {
      setDetailsLoading(false);
    }
  };

  useEffect(() => {
    fetchEvents();

    // Realtime subscriptions for event changes & registrations
    const unsubRegs = supabaseAdmin.subscribeToRegistrations(() => {
      fetchEvents();
      if (selectedEventRef.current) {
        supabaseAdmin.getEventRegistrations(selectedEventRef.current.id).then(setRegistrations);
      }
    });

    const unsubEvents = supabaseAdmin.subscribeToEvents(() => {
      fetchEvents();
    });

    return () => {
      unsubRegs();
      unsubEvents();
    };
  }, []);

  // Realtime subscription for submissions & votes on selected event
  useEffect(() => {
    if (!selectedEvent) return;

    const unsubSubs = supabaseAdmin.subscribeToProjectSubmissions(selectedEvent.id, () => {
      supabaseAdmin.getProjectSubmissions(selectedEvent.id).then(setProjectSubmissions);
      supabaseAdmin.getProjectVotingResults(selectedEvent.id).then(setVotingResults);
    });

    const unsubVotes = supabaseAdmin.subscribeToProjectVotes(selectedEvent.id, () => {
      supabaseAdmin.getProjectVotingResults(selectedEvent.id).then(setVotingResults);
    });

    return () => {
      unsubSubs();
      unsubVotes();
    };
  }, [selectedEvent?.id]);

  const handleOpenCreate = () => {
    setEditingId(null);
    setFormData({
      title: '',
      description: '',
      event_type: 'Technical',
      venue: 'Campus Auditorium',
      event_date: new Date().toISOString().split('T')[0],
      start_time: '10:00 AM',
      end_time: '04:00 PM',
      max_capacity: 100,
      participation_type: 'Individual',
      min_team_size: 1,
      max_team_size: 1,
      is_project_submission_enabled: false,
      project_submission_deadline: '',
      is_voting_enabled: false,
      voting_start: '',
      voting_end: '',
      voting_eligible_roles: 'STUDENT,STAFF',
    });
    setIsCreateOpen(true);
  };

  const handleOpenEdit = (ev) => {
    setEditingId(ev.id);
    setFormData({
      title: ev.title || '',
      description: ev.description || '',
      event_type: ev.event_type || 'Technical',
      venue: ev.venue || 'Campus Auditorium',
      event_date: ev.event_date || new Date().toISOString().split('T')[0],
      start_time: ev.start_time || '10:00 AM',
      end_time: ev.end_time || '04:00 PM',
      max_capacity: ev.max_capacity || 100,
      participation_type: ev.participation_type || 'Individual',
      min_team_size: ev.min_team_size || 1,
      max_team_size: ev.max_team_size || 1,
      is_project_submission_enabled: ev.is_project_submission_enabled || false,
      project_submission_deadline: ev.project_submission_deadline ? ev.project_submission_deadline.substring(0, 16) : '',
      is_voting_enabled: ev.is_voting_enabled || false,
      voting_start: ev.voting_start ? ev.voting_start.substring(0, 16) : '',
      voting_end: ev.voting_end ? ev.voting_end.substring(0, 16) : '',
      voting_eligible_roles: ev.voting_eligible_roles || 'STUDENT,STAFF',
    });
    setIsCreateOpen(true);
  };

  const handleSaveEvent = async (e) => {
    e.preventDefault();
    if (!formData.title.trim()) return;

    try {
      const payload = {
        title: formData.title.trim(),
        description: formData.description.trim(),
        event_type: formData.event_type,
        venue: formData.venue.trim(),
        event_date: formData.event_date,
        start_time: formData.start_time,
        end_time: formData.end_time,
        max_capacity: parseInt(formData.max_capacity) || 100,
        participation_type: formData.participation_type,
        min_team_size: formData.participation_type === 'Team' ? parseInt(formData.min_team_size) || 2 : 1,
        max_team_size: formData.participation_type === 'Team' ? parseInt(formData.max_team_size) || 4 : 1,
        is_project_submission_enabled: formData.is_project_submission_enabled,
        project_submission_deadline: formData.is_project_submission_enabled && formData.project_submission_deadline
          ? new Date(formData.project_submission_deadline).toISOString()
          : null,
        is_voting_enabled: formData.is_voting_enabled,
        voting_start: formData.is_voting_enabled && formData.voting_start
          ? new Date(formData.voting_start).toISOString()
          : null,
        voting_end: formData.is_voting_enabled && formData.voting_end
          ? new Date(formData.voting_end).toISOString()
          : null,
        voting_eligible_roles: formData.voting_eligible_roles,
      };

      if (editingId) {
        await supabaseAdmin.updateEvent(editingId, payload);
      } else {
        await supabaseAdmin.createEvent(payload);
      }

      setIsCreateOpen(false);
      fetchEvents();
      if (selectedEvent && selectedEvent.id === editingId) {
        const updated = await supabaseAdmin.getEvents();
        const cur = updated.find((ev) => ev.id === editingId);
        if (cur) setSelectedEvent(cur);
      }
    } catch (err) {
      alert('Error saving event: ' + err.message);
    }
  };

  const handleDeleteEvent = async (id, title) => {
    if (!window.confirm(`Are you sure you want to delete event "${title}"?`)) return;
    try {
      await supabaseAdmin.deleteEvent(id);
      if (selectedEvent && selectedEvent.id === id) {
        setSelectedEvent(null);
      }
      fetchEvents();
    } catch (err) {
      alert('Error deleting event: ' + err.message);
    }
  };

  const handleTogglePublish = async (submissionId, currentStatus) => {
    const newStatus = currentStatus === 'PUBLISHED' ? 'PENDING' : 'PUBLISHED';
    try {
      if (newStatus === 'PUBLISHED') {
        await supabaseAdmin.publishProjectSubmission(submissionId);
      } else {
        await supabaseAdmin.unpublishProjectSubmission(submissionId);
      }
      if (selectedEvent) {
        const updated = await supabaseAdmin.getProjectSubmissions(selectedEvent.id);
        setProjectSubmissions(updated);
      }
    } catch (err) {
      alert('Error changing project status: ' + err.message);
    }
  };

  // ──────────────────────────────────────────────────────────────────────────
  // VIEW: Event Details (when an event is selected)
  // ──────────────────────────────────────────────────────────────────────────
  if (selectedEvent) {
    const isTeam = selectedEvent.participation_type === 'Team';
    const isClosed = selectedEvent.status === 'COMPLETED' || selectedEvent.status === 'CANCELLED';

    return (
      <div className="page-container">
        <div className="page-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <button onClick={() => setSelectedEvent(null)} className="btn btn-secondary btn-sm">
              <ArrowLeft size={14} />
              <span>Back to Events</span>
            </button>
            <div>
              <h2>{selectedEvent.title}</h2>
              <p>{selectedEvent.venue} • {selectedEvent.event_date}</p>
            </div>
          </div>
          <div style={{ display: 'flex', gap: '8px' }}>
            <button onClick={() => handleOpenEdit(selectedEvent)} className="btn btn-secondary btn-sm">
              <Edit size={13} /> Edit Event
            </button>
            <button onClick={() => handleDeleteEvent(selectedEvent.id, selectedEvent.title)} className="btn btn-danger btn-sm">
              <Trash2 size={13} /> Delete
            </button>
          </div>
        </div>

        {/* Event Meta Summary Cards */}
        <div className="stat-boxes-grid">
          <div className="stat-box">
            <div className="stat-box-label">Date & Time</div>
            <div style={{ fontSize: '14px', fontWeight: '600', marginTop: '4px' }}>
              {selectedEvent.event_date}
            </div>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              {selectedEvent.start_time} - {selectedEvent.end_time}
            </div>
          </div>

          <div className="stat-box">
            <div className="stat-box-label">Venue</div>
            <div style={{ fontSize: '14px', fontWeight: '600', marginTop: '4px' }}>
              {selectedEvent.venue}
            </div>
          </div>

          <div className="stat-box">
            <div className="stat-box-label">Registration Status</div>
            <div style={{ marginTop: '4px' }}>
              <span className={`badge ${!isClosed ? 'badge-open' : 'badge-closed'}`}>
                {!isClosed ? 'Open' : 'Closed'}
              </span>
            </div>
          </div>

          <div className="stat-box">
            <div className="stat-box-label">Team Size</div>
            <div style={{ fontSize: '14px', fontWeight: '600', marginTop: '4px' }}>
              {isTeam ? `${selectedEvent.min_team_size} - ${selectedEvent.max_team_size} Members` : 'Individual'}
            </div>
          </div>

          <div className="stat-box highlight">
            <div className="stat-box-label">Participant Count</div>
            <div className="stat-box-value">
              {selectedEvent.registered_count ?? registrations.length} / {selectedEvent.max_capacity}
            </div>
          </div>
        </div>

        {/* 1. Registrations Section */}
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
            <h3 style={{ fontSize: '16px', fontWeight: '700' }}>
              Registrations ({registrations.length})
            </h3>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Live synchronized with Supabase
            </span>
          </div>

          {registrations.length === 0 ? (
            <div className="empty-state">No registrations yet</div>
          ) : (
            <div className="table-wrapper">
              <table className="simple-table">
                <thead>
                  <tr>
                    <th>Team / Student</th>
                    <th>Leader</th>
                    <th>Members</th>
                    <th>Registered At</th>
                  </tr>
                </thead>
                <tbody>
                  {registrations.map((reg) => {
                    const isTeamReg = reg.is_team_registration || reg.team_name;
                    const members = reg.members || [];
                    const leader = members.find((m) => m.isLeader) || members[0] || {};
                    const leaderText = leader.studentName
                      ? `${leader.studentName} (${leader.studentRoll || ''})`
                      : reg.user_id || 'Student';

                    return (
                      <tr key={reg.id}>
                        <td style={{ fontWeight: 600 }}>
                          {isTeamReg ? reg.team_name : (reg.student_name || leader.studentName || reg.user_id)}
                        </td>
                        <td>{leaderText}</td>
                        <td>
                          {isTeamReg ? (
                            <span title={members.map((m) => `${m.studentName} (${m.studentRoll})`).join(', ')}>
                              {members.length > 0 ? `${members.length} members` : 'Team'}
                            </span>
                          ) : (
                            '1 participant'
                          )}
                        </td>
                        <td style={{ color: 'var(--text-muted)' }}>
                          {reg.registered_at ? new Date(reg.registered_at).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }) : '-'}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* 2. Project Submissions Section (If enabled) */}
        {selectedEvent.is_project_submission_enabled && (
          <div className="card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
              <div>
                <h3 style={{ fontSize: '16px', fontWeight: '700' }}>Project Submissions</h3>
                {selectedEvent.project_submission_deadline && (
                  <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    Deadline: {new Date(selectedEvent.project_submission_deadline).toLocaleString()}
                  </span>
                )}
              </div>
            </div>

            {projectSubmissions.length === 0 ? (
              <div className="empty-state">No project submissions</div>
            ) : (
              <div className="table-wrapper">
                <table className="simple-table">
                  <thead>
                    <tr>
                      <th>Team</th>
                      <th>Project Name</th>
                      <th>Status</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {projectSubmissions.map((proj) => (
                      <tr key={proj.id}>
                        <td style={{ fontWeight: 600 }}>{proj.team_name}</td>
                        <td>{proj.project_name}</td>
                        <td>
                          <span className={`badge ${proj.status === 'PUBLISHED' ? 'badge-success' : 'badge-neutral'}`}>
                            {proj.status || 'SUBMITTED'}
                          </span>
                        </td>
                        <td>
                          <div style={{ display: 'flex', gap: '6px' }}>
                            <button
                              onClick={() => setViewingProject(proj)}
                              className="btn btn-secondary btn-sm"
                            >
                              View
                            </button>
                            <button
                              onClick={() => handleTogglePublish(proj.id, proj.status)}
                              className={`btn btn-sm ${proj.status === 'PUBLISHED' ? 'btn-danger' : 'btn-primary'}`}
                            >
                              {proj.status === 'PUBLISHED' ? 'Unpublish' : 'Publish'}
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {/* 3. Voting Results Section (If enabled) */}
        {selectedEvent.is_voting_enabled && (
          <div className="card">
            <div style={{ marginBottom: '14px' }}>
              <h3 style={{ fontSize: '16px', fontWeight: '700' }}>Voting Results</h3>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                Total Votes: {votingResults.totalVotes}. Visible only to administrators.
              </p>
            </div>

            {votingResults.projects.length === 0 ? (
              <div className="empty-state">No votes cast yet</div>
            ) : (
              <div className="table-wrapper">
                <table className="simple-table">
                  <thead>
                    <tr>
                      <th>Project</th>
                      <th>Votes</th>
                    </tr>
                  </thead>
                  <tbody>
                    {votingResults.projects.map((item) => (
                      <tr key={item.id}>
                        <td style={{ fontWeight: 600 }}>{item.project_name} ({item.team_name})</td>
                        <td style={{ fontWeight: 700, color: 'var(--primary)' }}>{item.vote_count ?? 0}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {/* Project Details Modal */}
        <Modal
          isOpen={!!viewingProject}
          onClose={() => setViewingProject(null)}
          title="Project Details"
        >
          {viewingProject && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <div style={{ fontSize: '11px', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
                  Team Name
                </div>
                <div style={{ fontSize: '15px', fontWeight: 700 }}>{viewingProject.team_name}</div>
              </div>

              <div>
                <div style={{ fontSize: '11px', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
                  Team Leader
                </div>
                <div style={{ fontSize: '14px', fontWeight: 600 }}>{viewingProject.leader_name}</div>
              </div>

              <div>
                <div style={{ fontSize: '11px', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
                  Project Name
                </div>
                <div style={{ fontSize: '15px', fontWeight: 700 }}>{viewingProject.project_name}</div>
              </div>

              <div>
                <div style={{ fontSize: '11px', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
                  Description
                </div>
                <div style={{ fontSize: '13px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                  {viewingProject.short_description}
                </div>
                {viewingProject.detailed_description && (
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '6px' }}>
                    {viewingProject.detailed_description}
                  </div>
                )}
              </div>

              {viewingProject.technologies && viewingProject.technologies.length > 0 && (
                <div>
                  <div style={{ fontSize: '11px', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
                    Technologies
                  </div>
                  <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap', marginTop: '4px' }}>
                    {viewingProject.technologies.map((t, idx) => (
                      <span key={idx} className="badge badge-neutral">{t}</span>
                    ))}
                  </div>
                </div>
              )}

              <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', marginTop: '6px' }}>
                {viewingProject.repo_url && (
                  <a
                    href={viewingProject.repo_url}
                    target="_blank"
                    rel="noreferrer"
                    className="btn btn-secondary btn-sm"
                  >
                    <ExternalLink size={13} /> Repository
                  </a>
                )}
                {viewingProject.demo_url && (
                  <a
                    href={viewingProject.demo_url}
                    target="_blank"
                    rel="noreferrer"
                    className="btn btn-secondary btn-sm"
                  >
                    <ExternalLink size={13} /> Live Demo
                  </a>
                )}
              </div>

              {viewingProject.image_url && (
                <div>
                  <div style={{ fontSize: '11px', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: '6px' }}>
                    Project Image
                  </div>
                  <img
                    src={viewingProject.image_url}
                    alt="Project preview"
                    style={{ maxWidth: '100%', maxHeight: '240px', borderRadius: '4px', border: '1px solid var(--border-color)' }}
                  />
                </div>
              )}
            </div>
          )}
        </Modal>
      </div>
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // VIEW: All Events Table (Main Events Page)
  // ──────────────────────────────────────────────────────────────────────────
  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h2>Events</h2>
          <p>College events, competitions, registrations, and project submissions</p>
        </div>
        <button onClick={handleOpenCreate} className="btn btn-primary">
          <Plus size={15} />
          <span>Create Event</span>
        </button>
      </div>

      {events.length === 0 && !isLoading ? (
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
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {events.map((ev) => {
                const isClosed = ev.status === 'COMPLETED' || ev.status === 'CANCELLED';
                const isTeam = ev.participation_type === 'Team';

                return (
                  <tr key={ev.id}>
                    <td style={{ fontWeight: 600 }}>{ev.title}</td>
                    <td>{ev.event_date || 'TBD'}</td>
                    <td>{isTeam ? 'Team' : 'Individual'}</td>
                    <td>
                      {ev.registered_count ?? 0} / {ev.max_capacity}
                    </td>
                    <td>
                      <span className={`badge ${!isClosed ? 'badge-open' : 'badge-closed'}`}>
                        {!isClosed ? 'Open' : 'Closed'}
                      </span>
                    </td>
                    <td>
                      <button
                        onClick={() => loadEventDetails(ev)}
                        className="btn btn-secondary btn-sm"
                      >
                        View
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* Create / Edit Modal */}
      <Modal
        isOpen={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
        title={editingId ? 'Edit Event' : 'Create Event'}
      >
        <form onSubmit={handleSaveEvent}>
          <div className="form-group">
            <label>Event Title *</label>
            <input
              type="text"
              className="form-control"
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              placeholder="e.g. Tech Quiz 2026, Idea Pitch"
              required
            />
          </div>

          <div className="form-group">
            <label>Description</label>
            <textarea
              className="form-control"
              rows={2}
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              placeholder="Brief overview of event rules and agenda"
            />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <div className="form-group">
              <label>Event Date</label>
              <input
                type="date"
                className="form-control"
                value={formData.event_date}
                onChange={(e) => setFormData({ ...formData, event_date: e.target.value })}
              />
            </div>

            <div className="form-group">
              <label>Venue</label>
              <input
                type="text"
                className="form-control"
                value={formData.venue}
                onChange={(e) => setFormData({ ...formData, venue: e.target.value })}
              />
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <div className="form-group">
              <label>Participation Type</label>
              <select
                className="form-control"
                value={formData.participation_type}
                onChange={(e) => setFormData({ ...formData, participation_type: e.target.value })}
              >
                <option value="Individual">Individual</option>
                <option value="Team">Team</option>
              </select>
            </div>

            <div className="form-group">
              <label>Max Capacity</label>
              <input
                type="number"
                className="form-control"
                value={formData.max_capacity}
                onChange={(e) => setFormData({ ...formData, max_capacity: e.target.value })}
              />
            </div>
          </div>

          {formData.participation_type === 'Team' && (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div className="form-group">
                <label>Min Team Size</label>
                <input
                  type="number"
                  className="form-control"
                  value={formData.min_team_size}
                  onChange={(e) => setFormData({ ...formData, min_team_size: e.target.value })}
                />
              </div>
              <div className="form-group">
                <label>Max Team Size</label>
                <input
                  type="number"
                  className="form-control"
                  value={formData.max_team_size}
                  onChange={(e) => setFormData({ ...formData, max_team_size: e.target.value })}
                />
              </div>
            </div>
          )}

          {/* Project Submission Toggle */}
          <div style={{ borderTop: '1px solid var(--border-color)', paddingTop: '12px', marginTop: '8px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: 600 }}>
              <input
                type="checkbox"
                checked={formData.is_project_submission_enabled}
                onChange={(e) => setFormData({ ...formData, is_project_submission_enabled: e.target.checked })}
              />
              <span>Enable Project Submissions</span>
            </label>

            {formData.is_project_submission_enabled && (
              <div className="form-group" style={{ marginTop: '10px' }}>
                <label>Project Submission Deadline</label>
                <input
                  type="datetime-local"
                  className="form-control"
                  value={formData.project_submission_deadline}
                  onChange={(e) => setFormData({ ...formData, project_submission_deadline: e.target.value })}
                />
              </div>
            )}
          </div>

          {/* Voting Toggle */}
          <div style={{ borderTop: '1px solid var(--border-color)', paddingTop: '12px', marginTop: '8px', marginBottom: '14px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: 600 }}>
              <input
                type="checkbox"
                checked={formData.is_voting_enabled}
                onChange={(e) => setFormData({ ...formData, is_voting_enabled: e.target.checked })}
              />
              <span>Enable Student / Staff Voting</span>
            </label>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
            <button type="button" onClick={() => setIsCreateOpen(false)} className="btn btn-secondary">
              Cancel
            </button>
            <button type="submit" className="btn btn-primary">
              {editingId ? 'Update Event' : 'Create Event'}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
