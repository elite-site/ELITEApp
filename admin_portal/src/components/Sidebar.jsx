import React from 'react';
import {
  LayoutDashboard,
  Radio,
  GraduationCap,
  Users,
  CalendarDays,
  BarChart3,
  ScanLine,
  FileText,
  Bell,
  Database,
  Settings,
  LogOut,
} from 'lucide-react';

export default function Sidebar({ activeTab, setActiveTab, metrics, onLogout }) {
  const navItems = [
    { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
    {
      id: 'live_sessions',
      label: 'Live Sessions',
      icon: Radio,
      badge: metrics?.onlineNow !== undefined ? `${metrics.onlineNow} live` : null,
      isLive: true,
    },
    { id: 'database', label: 'Database', icon: Database, badge: '22' },
    { id: 'students', label: 'Students', icon: GraduationCap, badge: metrics?.students || null },
    { id: 'staff', label: 'Staff', icon: Users, badge: metrics?.staff || null },
    { id: 'events', label: 'Events', icon: CalendarDays, badge: metrics?.events || null },
    { id: 'polls', label: 'Polls', icon: BarChart3, badge: metrics?.openPolls ? `${metrics.openPolls}` : null },
    { id: 'attendance', label: 'Attendance', icon: ScanLine },
    { id: 'reports', label: 'Reports', icon: FileText },
    { id: 'notifications', label: 'Notifications', icon: Bell },
    { id: 'settings', label: 'Settings', icon: Settings },
  ];

  return (
    <aside className="sidebar">
      {/* Brand Header */}
      <div className="sidebar-brand">
        <h1>ELITE</h1>
        <p>Information Technology</p>
      </div>

      {/* Navigation Links */}
      <nav className="sidebar-nav">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={`nav-item ${isActive ? 'active' : ''}`}
            >
              <div className="nav-item-left">
                <Icon size={16} className={item.isLive && metrics?.onlineNow > 0 ? 'pulse-icon-emerald' : ''} />
                <span>{item.label}</span>
              </div>
              {item.badge && (
                <span className={`nav-badge ${item.isLive ? 'nav-badge-live' : ''}`}>
                  {item.isLive && <span className="nav-live-dot"></span>}
                  {item.badge}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Logout Footer */}
      <div className="sidebar-footer">
        <button onClick={onLogout} className="logout-btn">
          <LogOut size={15} />
          <span>Logout</span>
        </button>
      </div>
    </aside>
  );
}
