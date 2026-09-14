import React, { useState, useEffect } from 'react';
import { Key, CheckCircle2, AlertCircle, RefreshCw, Server, ShieldCheck } from 'lucide-react';
import supabaseAdmin from '../services/supabase';

export default function SettingsView({ onCredentialsUpdated }) {
  const [url, setUrl] = useState(supabaseAdmin.url);
  const [key, setKey] = useState(supabaseAdmin.key);
  const [testResult, setTestResult] = useState(null);
  const [isTesting, setIsTesting] = useState(false);
  const [savedMessage, setSavedMessage] = useState('');

  const handleTestConnection = async () => {
    setIsTesting(true);
    setTestResult(null);
    try {
      const res = await supabaseAdmin.testConnection();
      setTestResult(res);
    } catch (e) {
      setTestResult({ ok: false, error: e.message });
    } finally {
      setIsTesting(false);
    }
  };

  useEffect(() => {
    handleTestConnection();
  }, []);

  const handleSave = (e) => {
    e.preventDefault();
    supabaseAdmin.updateCredentials(url, key);
    setSavedMessage('Supabase credentials successfully updated and active.');
    if (onCredentialsUpdated) onCredentialsUpdated();
    setTimeout(() => setSavedMessage(''), 4000);
    handleTestConnection();
  };

  const handleReset = () => {
    supabaseAdmin.resetCredentials();
    setUrl(supabaseAdmin.url);
    setKey(supabaseAdmin.key);
    setSavedMessage('Reset to default project credentials.');
    if (onCredentialsUpdated) onCredentialsUpdated();
    setTimeout(() => setSavedMessage(''), 4000);
    handleTestConnection();
  };

  return (
    <div className="page-container">
      {/* Top Banner */}
      <div className="card">
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
          <span className="badge badge-info">
            <Server size={12} style={{ marginRight: '4px' }} /> Backend Gateway
          </span>
          <span className="badge badge-success">
            <ShieldCheck size={12} style={{ marginRight: '4px' }} /> 100% Supabase Powered
          </span>
        </div>
        <h2 style={{ fontSize: '18px', fontWeight: '700', color: 'var(--text-main)' }}>
          Supabase PostgreSQL Connection & Settings
        </h2>
        <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginTop: '4px' }}>
          Manage your live Supabase endpoint and switch between Anon Public key and Service Role key.
        </p>
      </div>

      {/* Connection Status Card */}
      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
          <h3 style={{ fontSize: '15px', fontWeight: '600', color: 'var(--text-main)' }}>
            Database Diagnostics
          </h3>
          <button
            onClick={handleTestConnection}
            className="btn btn-secondary btn-sm"
            disabled={isTesting}
          >
            <RefreshCw size={13} />
            <span>{isTesting ? 'Testing...' : 'Test Connection'}</span>
          </button>
        </div>

        {testResult && (
          <div
            style={{
              padding: '12px 14px',
              borderRadius: '6px',
              background: testResult.ok ? '#f0fdf4' : '#fef2f2',
              border: `1px solid ${testResult.ok ? '#bbf7d0' : '#fecaca'}`,
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              marginBottom: '16px',
            }}
          >
            {testResult.ok ? (
              <CheckCircle2 size={18} color="#16a34a" />
            ) : (
              <AlertCircle size={18} color="#dc2626" />
            )}
            <div>
              <div style={{ fontWeight: '600', fontSize: '13px', color: testResult.ok ? '#15803d' : '#b91c1c' }}>
                {testResult.ok ? 'Database Connected & Operational' : 'Connection Failure'}
              </div>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                {testResult.ok
                  ? `Successfully authenticated to ${supabaseAdmin.url} via PostgreSQL client.`
                  : testResult.error}
              </div>
            </div>
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '10px' }}>
          {[
            { name: 'students', label: 'Student Enrolment (381)' },
            { name: 'staff', label: 'Faculty Coordinators' },
            { name: 'events', label: 'Events & Lineup' },
            { name: 'event_attendance', label: 'Attendance Scans' },
            { name: 'polls', label: 'Ballots & Polls' },
            { name: 'notifications', label: 'System Notifications' },
          ].map((t) => (
            <div
              key={t.name}
              style={{
                padding: '8px 12px',
                background: 'var(--bg-main)',
                borderRadius: '6px',
                border: '1px solid var(--border-color)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
              }}
            >
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{t.label}</span>
              <span className="badge badge-success">Ready</span>
            </div>
          ))}
        </div>
      </div>

      {/* Credential Form */}
      <div className="card">
        <h3 style={{ fontSize: '15px', fontWeight: '600', color: 'var(--text-main)', marginBottom: '14px' }}>
          API Endpoint & Security Credentials
        </h3>

        {savedMessage && (
          <div
            style={{
              padding: '10px 14px',
              borderRadius: '6px',
              background: '#f0fdf4',
              border: '1px solid #bbf7d0',
              color: '#15803d',
              fontSize: '13px',
              fontWeight: '600',
              marginBottom: '14px',
            }}
          >
            {savedMessage}
          </div>
        )}

        <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div className="form-group">
            <label>Supabase Project URL</label>
            <input
              type="text"
              className="form-control"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label>Supabase API Key (Anon Public Key or Service Role Key)</label>
            <textarea
              className="form-control"
              value={key}
              onChange={(e) => setKey(e.target.value)}
              rows={3}
              required
            />
            <span style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>
              Paste a <strong>service_role</strong> secret key to bypass Row Level Security (RLS) for complete admin overrides.
            </span>
          </div>

          <div style={{ display: 'flex', gap: '10px', marginTop: '6px' }}>
            <button type="submit" className="btn btn-primary">
              <Key size={14} />
              <span>Apply & Save Credentials</span>
            </button>
            <button type="button" onClick={handleReset} className="btn btn-secondary">
              Reset to Project Defaults
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
