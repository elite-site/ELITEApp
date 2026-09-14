import React, { useState, useEffect } from 'react';
import { LifeBuoy, CheckCircle2, Clock, AlertCircle, User, MessageSquare } from 'lucide-react';
import supabaseAdmin from '../services/supabase';
import Modal from '../components/Modal';

export default function TicketsView() {
  const [tickets, setTickets] = useState([]);
  const [statusFilter, setStatusFilter] = useState('All');
  const [isLoading, setIsLoading] = useState(false);

  // Detail Modal
  const [selectedTicket, setSelectedTicket] = useState(null);
  const [mentorInput, setMentorInput] = useState('');
  const [isDetailOpen, setIsDetailOpen] = useState(false);

  const fetchTickets = async () => {
    setIsLoading(true);
    try {
      const data = await supabaseAdmin.getTickets();
      setTickets(data);
    } catch (e) {
      console.error(e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchTickets();
  }, []);

  const handleUpdateStatus = async (ticketId, newStatus, mentor = null) => {
    try {
      await supabaseAdmin.updateTicketStatus(ticketId, newStatus, mentor);
      if (selectedTicket && selectedTicket.id === ticketId) {
        setSelectedTicket({ ...selectedTicket, status: newStatus, mentor: mentor || selectedTicket.mentor });
      }
      fetchTickets();
    } catch (err) {
      alert('Error updating ticket: ' + err.message);
    }
  };

  const filtered = tickets.filter((t) => {
    if (statusFilter === 'All') return true;
    return (t.status || 'QUEUED').toUpperCase() === statusFilter.toUpperCase();
  });

  return (
    <div className="page-container">
      {/* Top Banner */}
      <div className="toolbar">
        <div>
          <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '18px', fontWeight: '700' }}>
            Student Queries & Helpdesk Console
          </h3>
          <p style={{ color: 'var(--text-muted)', fontSize: '12px' }}>
            Lab support requests, turnstile credential resets, and academic mentor allocation.
          </p>
        </div>

        <div className="filter-group">
          {['All', 'QUEUED', 'IN_PROGRESS', 'RESOLVED'].map((st) => (
            <button
              key={st}
              className={`filter-btn ${statusFilter === st ? 'active' : ''}`}
              onClick={() => setStatusFilter(st)}
            >
              {st}
            </button>
          ))}
        </div>
      </div>

      {/* Tickets List */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
        {filtered.map((ticket) => {
          const status = (ticket.status || 'QUEUED').toUpperCase();
          const isResolved = status === 'RESOLVED';
          const isProgress = status === 'IN_PROGRESS';

          return (
            <div
              key={ticket.id}
              className="glass-card"
              style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}
            >
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', flex: 1, minWidth: '280px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span className="badge badge-indigo">{ticket.id}</span>
                  <span
                    className={`badge ${
                      isResolved ? 'badge-emerald' : isProgress ? 'badge-amber' : 'badge-rose'
                    }`}
                  >
                    {status}
                  </span>
                  <span style={{ fontSize: '12px', color: 'var(--text-dim)' }}>
                    Category: {ticket.category || 'Lab Support'}
                  </span>
                </div>

                <h4 style={{ fontSize: '15px', fontWeight: '700', color: '#ffffff' }}>
                  {ticket.title}
                </h4>

                <p style={{ color: 'var(--text-muted)', fontSize: '13px' }}>
                  {ticket.description}
                </p>

                <div style={{ display: 'flex', alignItems: 'center', gap: '14px', fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>
                  <span>Student: <strong>{ticket.student_name}</strong> ({ticket.roll_no})</span>
                  <span>Mentor Assigned: <strong>{ticket.mentor || 'IT Helpdesk'}</strong></span>
                </div>
              </div>

              {/* Status Action Buttons */}
              <div style={{ display: 'flex', gap: '8px' }}>
                {status !== 'RESOLVED' && (
                  <button
                    onClick={() => handleUpdateStatus(ticket.id, 'RESOLVED')}
                    className="btn btn-primary"
                    style={{ padding: '6px 12px', fontSize: '12px' }}
                  >
                    <CheckCircle2 size={13} />
                    <span>Resolve</span>
                  </button>
                )}
                {status === 'QUEUED' && (
                  <button
                    onClick={() => handleUpdateStatus(ticket.id, 'IN_PROGRESS')}
                    className="btn btn-secondary"
                    style={{ padding: '6px 12px', fontSize: '12px' }}
                  >
                    <Clock size={13} />
                    <span>Mark In Progress</span>
                  </button>
                )}
                <button
                  onClick={() => {
                    setSelectedTicket(ticket);
                    setMentorInput(ticket.mentor || 'IT Helpdesk');
                    setIsDetailOpen(true);
                  }}
                  className="btn btn-secondary"
                  style={{ padding: '6px 12px', fontSize: '12px' }}
                >
                  Details
                </button>
              </div>
            </div>
          );
        })}

        {filtered.length === 0 && !isLoading && (
          <div className="glass-card" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-dim)' }}>
            No tickets found with the selected filter.
          </div>
        )}
      </div>

      {/* Detail & Mentor Assign Modal */}
      <Modal
        isOpen={isDetailOpen}
        onClose={() => setIsDetailOpen(false)}
        title={selectedTicket ? `Ticket ${selectedTicket.id}` : 'Ticket Details'}
        footer={
          <>
            <button onClick={() => setIsDetailOpen(false)} className="btn btn-secondary">
              Close
            </button>
            <button
              onClick={() => {
                if (selectedTicket) {
                  handleUpdateStatus(selectedTicket.id, selectedTicket.status, mentorInput);
                  setIsDetailOpen(false);
                }
              }}
              className="btn btn-primary"
            >
              Update Assignee
            </button>
          </>
        }
      >
        {selectedTicket && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div>
              <label style={{ fontSize: '11px', color: 'var(--text-dim)', textTransform: 'uppercase', fontWeight: '700' }}>
                Student Information
              </label>
              <div style={{ marginTop: '4px', fontSize: '14px', fontWeight: '600', color: '#ffffff' }}>
                {selectedTicket.student_name} ({selectedTicket.roll_no})
              </div>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                {selectedTicket.email} • {selectedTicket.year_level}
              </div>
            </div>

            <div>
              <label style={{ fontSize: '11px', color: 'var(--text-dim)', textTransform: 'uppercase', fontWeight: '700' }}>
                Subject / Issue
              </label>
              <div style={{ marginTop: '4px', fontSize: '14px', color: '#ffffff' }}>
                {selectedTicket.title}
              </div>
              <p style={{ marginTop: '6px', fontSize: '13px', color: 'var(--text-muted)', background: 'rgba(0,0,0,0.2)', padding: '10px', borderRadius: '8px' }}>
                {selectedTicket.description}
              </p>
            </div>

            <div className="form-group">
              <label>Assigned Faculty / Mentor</label>
              <input
                type="text"
                className="form-control"
                value={mentorInput}
                onChange={(e) => setMentorInput(e.target.value)}
              />
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
