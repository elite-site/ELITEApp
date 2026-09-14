import React, { useState, useEffect } from 'react';
import { Plus, Trash2, Eye, Upload } from 'lucide-react';
import supabaseAdmin from '../services/supabase';
import Modal from '../components/Modal';

export default function PollsView() {
  const [polls, setPolls] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isAddOpen, setIsAddOpen] = useState(false);

  // View Results Modal
  const [selectedPoll, setSelectedPoll] = useState(null);

  // New Poll form
  const [question, setQuestion] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('Department');
  const [options, setOptions] = useState([
    { text: '', description: '', imageUrl: '' },
    { text: '', description: '', imageUrl: '' },
  ]);
  const [uploadingIdx, setUploadingIdx] = useState(null);

  const fetchPolls = async () => {
    setIsLoading(true);
    try {
      const data = await supabaseAdmin.getPolls();
      setPolls(data);
    } catch (e) {
      console.error('Error fetching polls:', e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchPolls();

    const unsub = supabaseAdmin.subscribeToPollVotes(() => {
      fetchPolls();
    });

    return () => {
      unsub();
    };
  }, []);

  const handleImageUpload = async (idx, file) => {
    if (!file) return;
    setUploadingIdx(idx);
    try {
      const url = await supabaseAdmin.uploadPollImage(file);
      const newOpts = [...options];
      newOpts[idx].imageUrl = url;
      setOptions(newOpts);
    } catch (err) {
      alert('Error uploading poll image: ' + err.message);
    } finally {
      setUploadingIdx(null);
    }
  };

  const handleCreatePoll = async (e) => {
    e.preventDefault();
    const validOptions = options.filter((o) => o.text && o.text.trim().length > 0);
    if (!question.trim() || validOptions.length < 2) {
      alert('Please provide a question and at least 2 options.');
      return;
    }

    try {
      await supabaseAdmin.createPoll({
        question: question.trim(),
        description: description.trim(),
        category,
        options: validOptions,
      });
      setIsAddOpen(false);
      setQuestion('');
      setDescription('');
      setOptions([
        { text: '', description: '', imageUrl: '' },
        { text: '', description: '', imageUrl: '' },
      ]);
      fetchPolls();
    } catch (err) {
      alert('Error creating poll: ' + err.message);
    }
  };

  const handleToggleStatus = async (poll) => {
    const newStatus = poll.status === 'OPEN' ? 'CLOSED' : 'OPEN';
    try {
      await supabaseAdmin.updatePollStatus(poll.id, newStatus);
      fetchPolls();
      if (selectedPoll && selectedPoll.id === poll.id) {
        setSelectedPoll({ ...selectedPoll, status: newStatus });
      }
    } catch (err) {
      alert('Error changing poll status: ' + err.message);
    }
  };

  const handleDeletePoll = async (pollId, pollTitle) => {
    if (!window.confirm(`Delete poll "${pollTitle}"?`)) return;
    try {
      await supabaseAdmin.deletePoll(pollId);
      if (selectedPoll && selectedPoll.id === pollId) {
        setSelectedPoll(null);
      }
      fetchPolls();
    } catch (err) {
      alert('Error deleting poll: ' + err.message);
    }
  };

  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h2>Polls</h2>
          <p>Department governance and student opinion polls</p>
        </div>
        <button onClick={() => setIsAddOpen(true)} className="btn btn-primary">
          <Plus size={15} />
          <span>Create Poll</span>
        </button>
      </div>

      {polls.length === 0 && !isLoading ? (
        <div className="empty-state">No active polls</div>
      ) : (
        <div className="table-wrapper">
          <table className="simple-table">
            <thead>
              <tr>
                <th>Poll Name</th>
                <th>Status</th>
                <th>Category</th>
                <th>Total Votes</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {polls.map((poll) => {
                const isOpen = poll.status === 'OPEN';
                return (
                  <tr key={poll.id}>
                    <td style={{ fontWeight: 600 }}>{poll.question}</td>
                    <td>
                      <span className={`badge ${isOpen ? 'badge-open' : 'badge-closed'}`}>
                        {isOpen ? 'Open' : 'Closed'}
                      </span>
                    </td>
                    <td>{poll.category || 'General'}</td>
                    <td style={{ fontWeight: 600 }}>{poll.total_votes ?? poll.totalVotes ?? 0}</td>
                    <td>
                      <div style={{ display: 'flex', gap: '6px' }}>
                        <button
                          onClick={() => setSelectedPoll(poll)}
                          className="btn btn-secondary btn-sm"
                        >
                          <Eye size={13} /> View Results
                        </button>
                        <button
                          onClick={() => handleToggleStatus(poll)}
                          className="btn btn-secondary btn-sm"
                        >
                          {isOpen ? 'Close' : 'Open'}
                        </button>
                        <button
                          onClick={() => handleDeletePoll(poll.id, poll.question)}
                          className="btn btn-danger btn-sm"
                        >
                          <Trash2 size={13} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* View Results Modal (Simple Table, Zero Charts) */}
      <Modal
        isOpen={!!selectedPoll}
        onClose={() => setSelectedPoll(null)}
        title="Poll Results (Admin Only)"
      >
        {selectedPoll && (
          <div>
            <div style={{ marginBottom: '14px' }}>
              <div style={{ fontSize: '16px', fontWeight: 700 }}>{selectedPoll.question}</div>
              {selectedPoll.description && (
                <div style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '2px' }}>
                  {selectedPoll.description}
                </div>
              )}
              <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '6px' }}>
                Status: <strong>{selectedPoll.status}</strong> • Total Votes: <strong>{selectedPoll.total_votes ?? selectedPoll.totalVotes ?? 0}</strong>
              </div>
            </div>

            <div className="table-wrapper">
              <table className="simple-table">
                <thead>
                  <tr>
                    <th>Option</th>
                    <th>Votes</th>
                    <th>Percentage</th>
                  </tr>
                </thead>
                <tbody>
                  {(selectedPoll.options || []).map((opt, i) => {
                    const total = selectedPoll.total_votes ?? selectedPoll.totalVotes ?? 0;
                    const votes = opt.votes ?? opt.vote_count ?? 0;
                    const pct = total > 0 ? ((votes / total) * 100).toFixed(1) : '0.0';

                    return (
                      <tr key={i}>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                            {opt.imageUrl && (
                              <img
                                src={opt.imageUrl}
                                alt={opt.text}
                                style={{ width: '32px', height: '32px', objectFit: 'cover', borderRadius: '4px', border: '1px solid var(--border-color)' }}
                              />
                            )}
                            <div>
                              <div style={{ fontWeight: 600 }}>{opt.text}</div>
                              {opt.description && (
                                <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{opt.description}</div>
                              )}
                            </div>
                          </div>
                        </td>
                        <td style={{ fontWeight: 700 }}>{votes}</td>
                        <td style={{ color: 'var(--text-secondary)' }}>{pct}%</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </Modal>

      {/* Create Poll Modal */}
      <Modal
        isOpen={isAddOpen}
        onClose={() => setIsAddOpen(false)}
        title="Create Department Poll"
      >
        <form onSubmit={handleCreatePoll}>
          <div className="form-group">
            <label>Poll Question *</label>
            <input
              type="text"
              className="form-control"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              placeholder="e.g. Which elective workshop should be scheduled next month?"
              required
            />
          </div>

          <div className="form-group">
            <label>Description / Context</label>
            <input
              type="text"
              className="form-control"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Brief details regarding the poll"
            />
          </div>

          <div className="form-group">
            <label>Category</label>
            <select
              className="form-control"
              value={category}
              onChange={(e) => setCategory(e.target.value)}
            >
              <option value="Department">Department</option>
              <option value="Symposium">Symposium</option>
              <option value="Academics">Academics</option>
              <option value="Facilities">Facilities</option>
            </select>
          </div>

          <div style={{ marginTop: '14px', marginBottom: '14px' }}>
            <label style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-secondary)' }}>
              Poll Options (Min 2)
            </label>

            {options.map((opt, idx) => (
              <div
                key={idx}
                style={{
                  border: '1px solid var(--border-color)',
                  borderRadius: '4px',
                  padding: '10px',
                  marginTop: '8px',
                  backgroundColor: 'var(--bg-subtle)',
                }}
              >
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                  <input
                    type="text"
                    className="form-control"
                    placeholder={`Option ${idx + 1} Name *`}
                    value={opt.text}
                    onChange={(e) => {
                      const copy = [...options];
                      copy[idx].text = e.target.value;
                      setOptions(copy);
                    }}
                    required={idx < 2}
                  />

                  {options.length > 2 && (
                    <button
                      type="button"
                      onClick={() => setOptions(options.filter((_, i) => i !== idx))}
                      className="btn btn-danger btn-sm"
                    >
                      <Trash2 size={13} />
                    </button>
                  )}
                </div>

                <div style={{ display: 'flex', gap: '8px', alignItems: 'center', marginTop: '6px' }}>
                  <input
                    type="text"
                    className="form-control"
                    placeholder="Short description (optional)"
                    value={opt.description}
                    onChange={(e) => {
                      const copy = [...options];
                      copy[idx].description = e.target.value;
                      setOptions(copy);
                    }}
                  />

                  <label className="btn btn-secondary btn-sm" style={{ cursor: 'pointer', whiteSpace: 'nowrap' }}>
                    <Upload size={12} />
                    <span>{uploadingIdx === idx ? 'Uploading...' : 'Image'}</span>
                    <input
                      type="file"
                      accept="image/*"
                      style={{ display: 'none' }}
                      onChange={(e) => {
                        if (e.target.files?.[0]) handleImageUpload(idx, e.target.files[0]);
                      }}
                    />
                  </label>
                </div>

                {opt.imageUrl && (
                  <div style={{ marginTop: '6px', fontSize: '11px', color: 'var(--success-text)' }}>
                    ✓ Image attached
                  </div>
                )}
              </div>
            ))}

            {options.length < 6 && (
              <button
                type="button"
                onClick={() => setOptions([...options, { text: '', description: '', imageUrl: '' }])}
                className="btn btn-secondary btn-sm"
                style={{ marginTop: '10px' }}
              >
                + Add Option
              </button>
            )}
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
            <button type="button" onClick={() => setIsAddOpen(false)} className="btn btn-secondary">
              Cancel
            </button>
            <button type="submit" className="btn btn-primary">
              Create Poll
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
