import React, { useState, useEffect } from 'react';
import { Plus } from 'lucide-react';
import supabaseAdmin from '../services/supabase';
import Modal from '../components/Modal';

export default function BroadcastView({ isBroadcastOpen, setIsBroadcastOpen }) {
  const [notifications, setNotifications] = useState([]);
  const [isLoading, setIsLoading] = useState(false);

  // Form
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [category, setCategory] = useState('General');
  const [targetAudience, setTargetAudience] = useState('ALL');
  const [isSending, setIsSending] = useState(false);

  const fetchNotifs = async () => {
    setIsLoading(true);
    try {
      const data = await supabaseAdmin.getNotifications({ limit: 50 });
      setNotifications(data);
    } catch (e) {
      console.error('Error fetching notifications:', e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchNotifs();
  }, []);

  const handleSendNotification = async (e) => {
    e.preventDefault();
    if (!title.trim() || !message.trim()) return;

    setIsSending(true);
    try {
      await supabaseAdmin.broadcastNotification({
        title: title.trim(),
        message: message.trim(),
        category,
        target_audience: targetAudience,
      });
      setIsBroadcastOpen(false);
      setTitle('');
      setMessage('');
      fetchNotifs();
    } catch (err) {
      alert('Error broadcasting notice: ' + err.message);
    } finally {
      setIsSending(false);
    }
  };

  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h2>Notifications</h2>
          <p>Department broadcasts and notices sent to student & staff mobile apps</p>
        </div>
        <button onClick={() => setIsBroadcastOpen(true)} className="btn btn-primary">
          <Plus size={14} />
          <span>New Notification</span>
        </button>
      </div>

      {notifications.length === 0 && !isLoading ? (
        <div className="empty-state">No notifications found</div>
      ) : (
        <div className="table-wrapper">
          <table className="simple-table">
            <thead>
              <tr>
                <th>Title</th>
                <th>Message</th>
                <th>Audience</th>
                <th>Date</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {notifications.map((n) => (
                <tr key={n.id}>
                  <td style={{ fontWeight: 600 }}>{n.title}</td>
                  <td style={{ maxWidth: '350px' }}>{n.message}</td>
                  <td>
                    <span className="badge badge-neutral">
                      {n.target_audience || 'ALL'}
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-muted)' }}>
                    {n.created_at ? new Date(n.created_at).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }) : '-'}
                  </td>
                  <td>
                    <span className="badge badge-success">Sent</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* New Notification Modal */}
      <Modal
        isOpen={isBroadcastOpen}
        onClose={() => setIsBroadcastOpen(false)}
        title="Send Department Notification"
      >
        <form onSubmit={handleSendNotification}>
          <div className="form-group">
            <label>Title *</label>
            <input
              type="text"
              className="form-control"
              placeholder="e.g. Lab Schedule Revision, Symposium Registration Open"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label>Message *</label>
            <textarea
              className="form-control"
              rows={4}
              placeholder="Enter the announcement message to broadcast"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              required
            />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <div className="form-group">
              <label>Target Audience</label>
              <select
                className="form-control"
                value={targetAudience}
                onChange={(e) => setTargetAudience(e.target.value)}
              >
                <option value="ALL">All Users</option>
                <option value="STUDENTS">Students Only</option>
                <option value="STAFF">Faculty & Staff</option>
              </select>
            </div>

            <div className="form-group">
              <label>Category</label>
              <select
                className="form-control"
                value={category}
                onChange={(e) => setCategory(e.target.value)}
              >
                <option value="General">General</option>
                <option value="Urgent">Urgent</option>
                <option value="Event">Event</option>
                <option value="Academics">Academics</option>
              </select>
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '16px' }}>
            <button type="button" onClick={() => setIsBroadcastOpen(false)} className="btn btn-secondary">
              Cancel
            </button>
            <button type="submit" disabled={isSending} className="btn btn-primary">
              {isSending ? 'Sending...' : 'Send Notification'}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
