import React from 'react';
import {
  LayoutDashboard,
  GraduationCap,
  Users,
  CalendarDays,
  BarChart3,
  ScanLine,
  FileText,
  Bell,
  Settings,
  LogOut,
} from 'lucide-react';

export default function Sidebar({ activeTab, setActiveTab, metrics, onLogout }) {
  const navItems = [
    { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
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
                <Icon size={16} />
                <span>{item.label}</span>
              </div>
              {item.badge && <span className="nav-badge">{item.badge}</span>}
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
