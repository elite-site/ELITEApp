import React, { useState, useEffect } from 'react';
import {
  Database,
  Plus,
  Trash2,
  Edit2,
  RefreshCw,
  Download,
  Terminal,
  Search,
  CheckCircle2,
  AlertCircle,
  Play,
  ArrowUpDown,
  FileCode,
} from 'lucide-react';
import supabaseAdmin from '../services/supabase';
import Modal from '../components/Modal';

export default function DatabaseView() {
  const tables = supabaseAdmin.getTableDefinitions();
  const [selectedTable, setSelectedTable] = useState(tables[0]);
  const [counts, setCounts] = useState({});
  const [records, setRecords] = useState([]);
  const [totalRecords, setTotalRecords] = useState(0);
  const [page, setPage] = useState(0);
  const [limit] = useState(25);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // SQL Console
  const [isSqlOpen, setIsSqlOpen] = useState(false);
  const [sqlQuery, setSqlQuery] = useState('SELECT table_name, (SELECT count(*) FROM information_schema.columns c WHERE c.table_name = t.table_name) as col_count FROM information_schema.tables t WHERE table_schema = \'public\' ORDER BY table_name;');
  const [sqlResult, setSqlResult] = useState(null);
  const [isExecutingSql, setIsExecutingSql] = useState(false);
  const [sqlError, setSqlError] = useState('');

  // Row Modals
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [editingRecord, setEditingRecord] = useState(null);
  const [rowFormData, setRowFormData] = useState({});

  // Fetch counts for all tables
  const loadCounts = async () => {
    try {
      const c = await supabaseAdmin.getTableCounts();
      setCounts(c);
    } catch (_) {}
  };

  // Fetch records for selected table
  const loadRecords = async () => {
    setIsLoading(true);
    setErrorMsg('');
    try {
      const res = await supabaseAdmin.getTableRecords(selectedTable.name, {
        page,
        limit,
      });
      setRecords(res.records || []);
      setTotalRecords(res.total || 0);
    } catch (err) {
      setErrorMsg(err.message || 'Error loading records');
      setRecords([]);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadCounts();
  }, []);

  useEffect(() => {
    setPage(0);
    setSearch('');
    loadRecords();
  }, [selectedTable]);

  useEffect(() => {
    loadRecords();
  }, [page]);

  // Determine columns from first available record or sample
  const columns = records.length > 0 ? Object.keys(records[0]) : [];

  // Filtered records by search term
  const filteredRecords = search.trim()
    ? records.filter((r) =>
        Object.values(r).some((v) =>
          String(v ?? '').toLowerCase().includes(search.toLowerCase())
        )
      )
    : records;

  // Insert Record
  const handleOpenAdd = () => {
    const initialData = {};
    columns.forEach((col) => {
      if (col === selectedTable.pk && (col === 'id' || col === 'user_id')) {
        initialData[col] = `${selectedTable.name.slice(0, 4)}_${Date.now()}`;
      } else {
        initialData[col] = '';
      }
    });
    setRowFormData(initialData);
    setIsAddOpen(true);
  };

  const handleSaveAdd = async (e) => {
    e.preventDefault();
    setIsLoading(true);
    try {
      const payload = { ...rowFormData };
      // Parse JSON or numeric fields if needed
      Object.keys(payload).forEach((k) => {
        const val = payload[k];
        if (typeof val === 'string' && (val.startsWith('{') || val.startsWith('['))) {
          try {
            payload[k] = JSON.parse(val);
          } catch (_) {}
        } else if (val === '') {
          delete payload[k]; // let database defaults populate
        }
      });

      await supabaseAdmin.insertTableRow(selectedTable.name, payload);
      setSuccessMsg(`Successfully inserted record into ${selectedTable.name}`);
      setIsAddOpen(false);
      loadRecords();
      loadCounts();
      setTimeout(() => setSuccessMsg(''), 4000);
    } catch (err) {
      alert('Error inserting record: ' + err.message);
    } finally {
      setIsLoading(false);
    }
  };

  // Edit Record
  const handleOpenEdit = (rec) => {
    setEditingRecord(rec);
    const formVals = {};
    Object.keys(rec).forEach((k) => {
      const val = rec[k];
      formVals[k] = typeof val === 'object' && val !== null ? JSON.stringify(val) : (val ?? '');
    });
    setRowFormData(formVals);
    setIsEditOpen(true);
  };

  const handleSaveEdit = async (e) => {
    e.preventDefault();
    if (!editingRecord) return;
    setIsLoading(true);
    try {
      const pkField = selectedTable.pk;
      const pkVal = editingRecord[pkField];
      const updates = { ...rowFormData };
      delete updates[pkField]; // Don't mutate primary key

      Object.keys(updates).forEach((k) => {
        const val = updates[k];
        if (typeof val === 'string' && (val.startsWith('{') || val.startsWith('['))) {
          try {
            updates[k] = JSON.parse(val);
          } catch (_) {}
        }
      });

      await supabaseAdmin.updateTableRow(selectedTable.name, pkField, pkVal, updates);
      setSuccessMsg(`Record updated successfully in ${selectedTable.name}`);
      setIsEditOpen(false);
      setEditingRecord(null);
      loadRecords();
      setTimeout(() => setSuccessMsg(''), 4000);
    } catch (err) {
      alert('Error updating record: ' + err.message);
    } finally {
      setIsLoading(false);
    }
  };

  // Delete Record
  const handleDeleteRow = async (rec) => {
    const pkField = selectedTable.pk;
    const pkVal = rec[pkField];
    if (!window.confirm(`Are you sure you want to delete row where ${pkField} = "${pkVal}" from table "${selectedTable.name}"?`)) {
      return;
    }

    try {
      await supabaseAdmin.deleteTableRow(selectedTable.name, pkField, pkVal);
      setSuccessMsg(`Deleted row (${pkField}: ${pkVal}) from ${selectedTable.name}`);
      loadRecords();
      loadCounts();
      setTimeout(() => setSuccessMsg(''), 4000);
    } catch (err) {
      alert('Error deleting row: ' + err.message);
    }
  };

  // Run Custom SQL
  const handleRunSql = async () => {
    if (!sqlQuery.trim()) return;
    setIsExecutingSql(true);
    setSqlError('');
    setSqlResult(null);
    try {
      const res = await supabaseAdmin.executeSql(sqlQuery);
      setSqlResult(res);
    } catch (err) {
      setSqlError(err.message);
    } finally {
      setIsExecutingSql(false);
    }
  };

  // Export CSV
  const handleExportCsv = () => {
    if (records.length === 0) return;
    const headers = columns.join(',');
    const rows = records.map((r) =>
      columns.map((c) => {
        const val = r[c];
        if (typeof val === 'object' && val !== null) {
          return `"${JSON.stringify(val).replace(/"/g, '""')}"`;
        }
        return `"${String(val ?? '').replace(/"/g, '""')}"`;
      }).join(',')
    );
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers, ...rows].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `supabase_${selectedTable.name}_${Date.now()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="page-container">
      {/* Top Header Card */}
      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
              <span className="badge badge-info">
                <Database size={12} style={{ marginRight: '4px' }} /> Database Manager
              </span>
              <span className="badge badge-success">
                21 PostgreSQL Tables
              </span>
            </div>
            <h2 style={{ fontSize: '18px', fontWeight: '700', color: 'var(--text-main)' }}>
              Supabase Central Database Control
            </h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginTop: '4px' }}>
              Complete administrative authority over all Supabase tables, schema rows, and direct queries.
            </p>
          </div>

          <div style={{ display: 'flex', gap: '8px' }}>
            <button
              onClick={() => setIsSqlOpen(!isSqlOpen)}
              className={`btn ${isSqlOpen ? 'btn-primary' : 'btn-secondary'}`}
            >
              <Terminal size={14} />
              <span>{isSqlOpen ? 'Hide SQL Console' : 'Open SQL Console'}</span>
            </button>
            <button onClick={() => { loadRecords(); loadCounts(); }} className="btn btn-secondary">
              <RefreshCw size={14} className={isLoading ? 'spin' : ''} />
              <span>Refresh</span>
            </button>
          </div>
        </div>

        {/* Success / Error Alerts */}
        {successMsg && (
          <div style={{ marginTop: '12px', padding: '10px 14px', borderRadius: '6px', background: '#f0fdf4', border: '1px solid #bbf7d0', color: '#166534', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <CheckCircle2 size={16} color="#16a34a" />
            <span>{successMsg}</span>
          </div>
        )}
        {errorMsg && (
          <div style={{ marginTop: '12px', padding: '10px 14px', borderRadius: '6px', background: '#fef2f2', border: '1px solid #fecaca', color: '#991b1b', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <AlertCircle size={16} color="#dc2626" />
            <span>{errorMsg}</span>
          </div>
        )}
      </div>

      {/* SQL Interactive Console */}
      {isSqlOpen && (
        <div className="card" style={{ borderLeft: '4px solid var(--primary)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <FileCode size={16} color="var(--primary)" />
              <h3 style={{ fontSize: '14px', fontWeight: '600' }}>Direct PostgreSQL Query Executor</h3>
            </div>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Executes via Supabase RPC</span>
          </div>

          <textarea
            value={sqlQuery}
            onChange={(e) => setSqlQuery(e.target.value)}
            rows={3}
            style={{
              width: '100%',
              fontFamily: 'Consolas, Monaco, monospace',
              fontSize: '13px',
              padding: '10px',
              borderRadius: '6px',
              border: '1px solid var(--border-color)',
              background: '#f8fafc',
              color: '#0f172a',
              resize: 'vertical',
            }}
            placeholder="SELECT * FROM students LIMIT 10;"
          />

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '8px' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Supports standard SELECT queries with instant JSONB result formatting.
            </span>
            <button
              onClick={handleRunSql}
              disabled={isExecutingSql}
              className="btn btn-primary btn-sm"
            >
              <Play size={12} />
              <span>{isExecutingSql ? 'Executing...' : 'Run Query'}</span>
            </button>
          </div>

          {sqlError && (
            <div style={{ marginTop: '10px', padding: '8px 12px', background: '#fef2f2', border: '1px solid #fecaca', color: '#dc2626', borderRadius: '4px', fontSize: '12px', fontFamily: 'monospace' }}>
              {sqlError}
            </div>
          )}

          {sqlResult && (
            <div style={{ marginTop: '10px', maxHeight: '240px', overflowY: 'auto', background: '#0f172a', color: '#38bdf8', padding: '12px', borderRadius: '6px', fontSize: '12px', fontFamily: 'Consolas, Monaco, monospace' }}>
              <pre style={{ margin: 0 }}>{JSON.stringify(sqlResult, null, 2)}</pre>
            </div>
          )}
        </div>
      )}

      {/* Table Navigation Selector Bar */}
      <div style={{ display: 'flex', gap: '8px', overflowX: 'auto', paddingBottom: '6px', scrollbarWidth: 'thin' }}>
        {tables.map((t) => {
          const isSelected = selectedTable.name === t.name;
          const count = counts[t.name] ?? '-';
          return (
            <button
              key={t.name}
              onClick={() => setSelectedTable(t)}
              style={{
                padding: '8px 14px',
                borderRadius: '6px',
                fontSize: '13px',
                fontWeight: isSelected ? '600' : '500',
                background: isSelected ? 'var(--primary)' : 'var(--card-bg)',
                color: isSelected ? '#ffffff' : 'var(--text-main)',
                border: isSelected ? '1px solid var(--primary)' : '1px solid var(--border-color)',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                whiteSpace: 'nowrap',
                cursor: 'pointer',
                transition: 'all 0.15s ease',
              }}
            >
              <span>{t.label}</span>
              <span
                style={{
                  fontSize: '11px',
                  padding: '2px 6px',
                  borderRadius: '10px',
                  background: isSelected ? 'rgba(255,255,255,0.25)' : '#f1f5f9',
                  color: isSelected ? '#ffffff' : '#64748b',
                }}
              >
                {count}
              </span>
            </button>
          );
        })}
      </div>

      {/* Action Toolbar for Selected Table */}
      <div className="toolbar">
        <div className="search-box">
          <Search size={16} className="search-icon" />
          <input
            type="text"
            placeholder={`Filter ${selectedTable.name} records in memory...`}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <button onClick={handleExportCsv} className="btn btn-secondary">
            <Download size={14} />
            <span>Export CSV</span>
          </button>
          <button onClick={handleOpenAdd} className="btn btn-primary">
            <Plus size={14} />
            <span>Insert Row</span>
          </button>
        </div>
      </div>

      {/* Record Count and Pagination */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <p style={{ color: 'var(--text-muted)', fontSize: '13px' }}>
          Table: <strong style={{ color: 'var(--text-main)' }}>public.{selectedTable.name}</strong> • Showing{' '}
          <strong>{filteredRecords.length}</strong> of <strong>{totalRecords}</strong> total rows (Primary Key: <code>{selectedTable.pk}</code>)
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
          <span style={{ fontSize: '12px', display: 'flex', alignItems: 'center', color: 'var(--text-muted)' }}>
            Page {page + 1} of {Math.max(1, Math.ceil(totalRecords / limit))}
          </span>
          <button
            className="btn btn-secondary"
            style={{ padding: '4px 10px', fontSize: '12px' }}
            disabled={(page + 1) * limit >= totalRecords}
            onClick={() => setPage((p) => p + 1)}
          >
            Next
          </button>
        </div>
      </div>

      {/* Dynamic Records Table */}
      <div className="table-wrapper">
        <table className="admin-table">
          <thead>
            <tr>
              <th style={{ width: '80px' }}>Actions</th>
              {columns.map((col) => (
                <th key={col}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <span>{col}</span>
                    {col === selectedTable.pk && (
                      <span style={{ fontSize: '9px', background: '#fef3c7', color: '#92400e', padding: '1px 4px', borderRadius: '3px' }}>PK</span>
                    )}
                  </div>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={columns.length + 1} style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                  Loading database records...
                </td>
              </tr>
            ) : filteredRecords.length === 0 ? (
              <tr>
                <td colSpan={columns.length + 1} style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                  No records found in table <strong>{selectedTable.name}</strong>.
                </td>
              </tr>
            ) : (
              filteredRecords.map((row, idx) => (
                <tr key={row[selectedTable.pk] ?? idx}>
                  <td>
                    <div style={{ display: 'flex', gap: '4px' }}>
                      <button
                        onClick={() => handleOpenEdit(row)}
                        className="btn-icon"
                        title="Edit Row"
                      >
                        <Edit2 size={13} />
                      </button>
                      <button
                        onClick={() => handleDeleteRow(row)}
                        className="btn-icon delete"
                        title="Delete Row"
                      >
                        <Trash2 size={13} />
                      </button>
                    </div>
                  </td>
                  {columns.map((col) => {
                    const val = row[col];
                    if (val === null || val === undefined) {
                      return <td key={col} style={{ color: '#cbd5e1', fontStyle: 'italic' }}>null</td>;
                    }
                    if (typeof val === 'boolean') {
                      return (
                        <td key={col}>
                          <span className={`badge ${val ? 'badge-success' : 'badge-danger'}`}>
                            {val ? 'TRUE' : 'FALSE'}
                          </span>
                        </td>
                      );
                    }
                    if (typeof val === 'object') {
                      return (
                        <td key={col} style={{ maxWidth: '240px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={JSON.stringify(val)}>
                          <code>{JSON.stringify(val)}</code>
                        </td>
                      );
                    }
                    return (
                      <td key={col} style={{ maxWidth: '240px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={String(val)}>
                        {String(val)}
                      </td>
                    );
                  })}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Insert Record Modal */}
      <Modal
        isOpen={isAddOpen}
        onClose={() => setIsAddOpen(false)}
        title={`Insert New Row into ${selectedTable.name}`}
      >
        <form onSubmit={handleSaveAdd}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', maxHeight: '60vh', overflowY: 'auto', paddingRight: '4px' }}>
            {columns.map((col) => (
              <div key={col} className="form-group" style={{ gridColumn: col.includes('description') || col.includes('content') || col.includes('members') ? '1 / -1' : 'auto' }}>
                <label style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span>{col}</span>
                  {col === selectedTable.pk && <span style={{ color: 'var(--primary)', fontSize: '11px' }}>Primary Key</span>}
                </label>
                {col.includes('description') || col.includes('content') || col.includes('members') ? (
                  <textarea
                    rows={3}
                    value={rowFormData[col] ?? ''}
                    onChange={(e) => setRowFormData({ ...rowFormData, [col]: e.target.value })}
                  />
                ) : (
                  <input
                    type="text"
                    value={rowFormData[col] ?? ''}
                    onChange={(e) => setRowFormData({ ...rowFormData, [col]: e.target.value })}
                  />
                )}
              </div>
            ))}
          </div>
          <div className="modal-actions" style={{ marginTop: '16px' }}>
            <button type="button" onClick={() => setIsAddOpen(false)} className="btn btn-secondary">
              Cancel
            </button>
            <button type="submit" className="btn btn-primary" disabled={isLoading}>
              Insert Row
            </button>
          </div>
        </form>
      </Modal>

      {/* Edit Record Modal */}
      <Modal
        isOpen={isEditOpen}
        onClose={() => { setIsEditOpen(false); setEditingRecord(null); }}
        title={`Edit Row in ${selectedTable.name} (${selectedTable.pk}: ${editingRecord?.[selectedTable.pk]})`}
      >
        <form onSubmit={handleSaveEdit}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', maxHeight: '60vh', overflowY: 'auto', paddingRight: '4px' }}>
            {columns.map((col) => (
              <div key={col} className="form-group" style={{ gridColumn: col.includes('description') || col.includes('content') || col.includes('members') ? '1 / -1' : 'auto' }}>
                <label style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span>{col}</span>
                  {col === selectedTable.pk && <span style={{ color: '#dc2626', fontSize: '11px' }}>Primary Key (Read-Only)</span>}
                </label>
                {col.includes('description') || col.includes('content') || col.includes('members') ? (
                  <textarea
                    rows={3}
                    disabled={col === selectedTable.pk}
                    value={rowFormData[col] ?? ''}
                    onChange={(e) => setRowFormData({ ...rowFormData, [col]: e.target.value })}
                  />
                ) : (
                  <input
                    type="text"
                    disabled={col === selectedTable.pk}
                    value={rowFormData[col] ?? ''}
                    onChange={(e) => setRowFormData({ ...rowFormData, [col]: e.target.value })}
                  />
                )}
              </div>
            ))}
          </div>
          <div className="modal-actions" style={{ marginTop: '16px' }}>
            <button type="button" onClick={() => { setIsEditOpen(false); setEditingRecord(null); }} className="btn btn-secondary">
              Cancel
            </button>
            <button type="submit" className="btn btn-primary" disabled={isLoading}>
              Save Changes
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
