import React from 'react';
import { LogOut } from 'lucide-react';

export default function Header({ adminName = 'Administrator', onLogout }) {
  return (
    <header className="top-header">
      <div className="header-left">
        <span className="header-title">ELITE Admin</span>
      </div>

      <div className="header-right">
        <span className="header-user">{adminName}</span>
        <button
          onClick={onLogout}
          className="btn btn-secondary btn-sm"
          title="Logout of admin session"
        >
          <LogOut size={13} />
          <span>Logout</span>
        </button>
      </div>
    </header>
  );
}
