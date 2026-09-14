import React, { useState, useEffect } from 'react';
import Sidebar from './components/Sidebar';
import Header from './components/Header';
import DashboardView from './views/DashboardView';
import StudentsView from './views/StudentsView';
import FacultyView from './views/FacultyView';
import EventsView from './views/EventsView';
import AttendanceView from './views/AttendanceView';
import PollsView from './views/PollsView';
import BroadcastView from './views/BroadcastView';
import ReportsView from './views/ReportsView';
import SettingsView from './views/SettingsView';
import DatabaseView from './views/DatabaseView';
import LiveSessionsView from './views/LiveSessionsView';
import ErrorBoundary from './components/ErrorBoundary';
import supabaseAdmin from './services/supabase';

export default function App() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [isConnected, setIsConnected] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Global counts and metrics
  const [metrics, setMetrics] = useState({
    students: 0,
    staff: 0,
    events: 0,
    registrations: 0,
    openPolls: 0,
    attendanceToday: 0,
    openTickets: 0,
    onlineNow: 0,
  });
  const [events, setEvents] = useState([]);
  const [recentAttendance, setRecentAttendance] = useState([]);

  // Quick modals triggers from dashboard
  const [isNewEventOpen, setIsNewEventOpen] = useState(false);
  const [isBroadcastOpen, setIsBroadcastOpen] = useState(false);
  const [isCheckInOpen, setIsCheckInOpen] = useState(false);

  const fetchGlobalData = async () => {
    setIsRefreshing(true);
    try {
      await supabaseAdmin.ensureAdminSession();
      const ping = await supabaseAdmin.testConnection();
      setIsConnected(ping.ok);

      const [m, sessionM] = await Promise.all([
        supabaseAdmin.getDashboardMetrics(),
        supabaseAdmin.getSessionMetrics().catch(() => ({ onlineNow: 0 })),
      ]);
      setMetrics({
        ...m,
        onlineNow: sessionM?.onlineNow ?? 0,
      });

      const evs = await supabaseAdmin.getEvents();
      setEvents(evs);

      const att = await supabaseAdmin.getAttendanceLogs({ limit: 10 });
      setRecentAttendance(att);
    } catch (e) {
      console.error('Data fetch error:', e);
      setIsConnected(false);
    } finally {
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    fetchGlobalData();

    // Real-time synchronization with Supabase events, registrations, and live sessions
    const unsubRegs = supabaseAdmin.subscribeToRegistrations(() => {
      fetchGlobalData();
    });
    const unsubEvents = supabaseAdmin.subscribeToEvents(() => {
      fetchGlobalData();
    });
    const unsubSessions = supabaseAdmin.subscribeToSessions(() => {
      fetchGlobalData();
    });

    return () => {
      unsubRegs();
      unsubEvents();
      unsubSessions();
    };
  }, []);

  const handleLogout = () => {
    if (window.confirm('Are you sure you want to log out of the administration panel?')) {
      supabaseAdmin.supabase.auth.signOut().catch(() => {});
      window.location.reload();
    }
  };

  return (
    <div className="app-layout">
      {/* Navigation Sidebar */}
      <Sidebar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        metrics={metrics}
        onLogout={handleLogout}
      />

      {/* Main Content Area */}
      <div className="main-wrapper">
        <Header
          adminName="Administrator"
          onLogout={handleLogout}
        />

        <main style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
          <ErrorBoundary>
            {activeTab === 'dashboard' && (
              <DashboardView
                metrics={metrics}
                events={events}
                recentAttendance={recentAttendance}
                isLoading={isRefreshing}
                onNavigate={setActiveTab}
                onOpenNewEvent={() => {
                  setActiveTab('events');
                  setIsNewEventOpen(true);
                }}
                onOpenBroadcast={() => {
                  setActiveTab('notifications');
                  setIsBroadcastOpen(true);
                }}
                onOpenCheckIn={() => {
                  setActiveTab('attendance');
                  setIsCheckInOpen(true);
                }}
              />
            )}

            {activeTab === 'live_sessions' && <LiveSessionsView />}

            {activeTab === 'database' && <DatabaseView />}

            {activeTab === 'students' && <StudentsView />}

            {activeTab === 'staff' && <FacultyView />}

            {activeTab === 'events' && (
              <EventsView
                isCreateOpen={isNewEventOpen}
                setIsCreateOpen={setIsNewEventOpen}
              />
            )}

            {activeTab === 'attendance' && (
              <AttendanceView
                isCheckInOpen={isCheckInOpen}
                setIsCheckInOpen={setIsCheckInOpen}
              />
            )}

            {activeTab === 'polls' && <PollsView />}

            {activeTab === 'reports' && <ReportsView />}

            {activeTab === 'notifications' && (
              <BroadcastView
                isBroadcastOpen={isBroadcastOpen}
                setIsBroadcastOpen={setIsBroadcastOpen}
              />
            )}

            {activeTab === 'settings' && (
              <SettingsView onCredentialsUpdated={fetchGlobalData} />
            )}
          </ErrorBoundary>
        </main>
      </div>
    </div>
  );
}
