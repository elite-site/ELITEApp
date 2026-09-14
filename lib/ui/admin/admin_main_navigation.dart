import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';

class AdminMainNavigation extends StatefulWidget {
  const AdminMainNavigation({super.key});

  @override
  State<AdminMainNavigation> createState() => _AdminMainNavigationState();
}

class _AdminMainNavigationState extends State<AdminMainNavigation> {
  int _selectedSectionIndex = 0;

  final List<Map<String, dynamic>> _sections = [
    {'title': 'Dashboard', 'icon': Icons.dashboard},
    {'title': 'Students', 'icon': Icons.people},
    {'title': 'Staff', 'icon': Icons.badge},
    {'title': 'Events', 'icon': Icons.event},
    {'title': 'Polls', 'icon': Icons.poll},
    {'title': 'Attendance', 'icon': Icons.qr_code_scanner},
    {'title': 'Reports', 'icon': Icons.analytics},
    {'title': 'Notifications', 'icon': Icons.campaign},
    {'title': 'Settings', 'icon': Icons.settings},
  ];

  // Attendance scanner manual input
  final TextEditingController _adminQrCtrl = TextEditingController();
  String? _adminScanFeedback;
  bool _adminScanSuccess = false;

  // Search queries
  String _studentSearch = '';

  // Notice composer
  final TextEditingController _notifTitleCtrl = TextEditingController();
  final TextEditingController _notifBodyCtrl = TextEditingController();

  @override
  void dispose() {
    _adminQrCtrl.dispose();
    _notifTitleCtrl.dispose();
    _notifBodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADMIN CONSOLE',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.primary),
            ),
            Text(
              _sections[_selectedSectionIndex]['title'],
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: state.isSupabaseConnected ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: state.isSupabaseConnected ? Colors.green : Colors.red),
                const SizedBox(width: 6),
                Text(
                  state.isSupabaseConnected ? 'Live Supabase' : 'Offline',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: state.isSupabaseConnected ? Colors.green : Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                ),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.admin_panel_settings, size: 36, color: Colors.white),
              ),
              accountName: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text('${user.email} (Super Admin)'),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _sections.length,
                itemBuilder: (ctx, idx) {
                  final sec = _sections[idx];
                  final isSel = _selectedSectionIndex == idx;
                  return ListTile(
                    dense: true,
                    leading: Icon(sec['icon'], color: isSel ? AppColors.primary : AppColors.onSurfaceVariant),
                    title: Text(
                      sec['title'],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? AppColors.primary : AppColors.onSurface,
                      ),
                    ),
                    selected: isSel,
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                    onTap: () {
                      setState(() => _selectedSectionIndex = idx);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              onTap: () {
                state.logout();
                context.go('/login');
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => state.syncFromSupabase(),
        child: _buildSectionContent(context, state, user),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // Map drawer indices 5-8 to bottom-nav index 4 ("More") so the
        // bottom bar always reflects a valid selected item.
        currentIndex: _selectedSectionIndex.clamp(0, 4),
        onTap: (idx) {
          if (idx == 4) {
            // Open drawer for "All Modules"
            Scaffold.of(context).openDrawer();
          } else {
            setState(() => _selectedSectionIndex = idx);
          }
        },
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Students'),
          BottomNavigationBarItem(icon: Icon(Icons.event_outlined), activeIcon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.poll_outlined), activeIcon: Icon(Icons.poll), label: 'Polls'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: 'More'),
        ],
      ),
    );
  }

  Widget _buildSectionContent(BuildContext context, AppState state, UserModel user) {
    switch (_selectedSectionIndex) {
      case 0:
        return _buildDashboardSection(context, state);
      case 1:
        return _buildStudentsSection(context, state);
      case 2:
        return _buildStaffSection(context, state);
      case 3:
        return _buildEventsSection(context, state);
      case 4:
        return _buildPollsSection(context, state);
      case 5:
        return _buildAttendanceSection(context, state);
      case 6:
        return _buildReportsSection(context, state);
      case 7:
        return _buildNotificationsSection(context, state);
      case 8:
        return _buildSettingsSection(context, state);
      default:
        return _buildDashboardSection(context, state);
    }
  }

  // ─── 0. Dashboard ─────────────────────────────────────────────────────────

  Widget _buildDashboardSection(BuildContext context, AppState state) {
    final totalReg = state.events.fold(0, (sum, e) => sum + (e.totalSeats - e.seatsLeft));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Department Telemetry', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),

          // KPI Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _kpiBox('Enrolled Students', '${state.studentsRoster.length}', Icons.school, AppColors.secondary),
              _kpiBox('Faculty Staff', '${state.staffRoster.length}', Icons.badge, AppColors.primary),
              _kpiBox('Active Events', '${state.events.length}', Icons.event, Colors.teal),
              _kpiBox('Total Registrations', '$totalReg', Icons.how_to_reg, Colors.orange),
              _kpiBox('Turnstile Scans', '${state.attendanceLogs.length}', Icons.qr_code_scanner, Colors.purple),
              _kpiBox('Active Polls', '${state.polls.length}', Icons.poll, Colors.blue),
            ],
          ),
          const SizedBox(height: 24),

          Text('Live Events Registration Gauge', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...state.events.map((e) {
            final cap = e.totalSeats;
            final reg = cap - e.seatsLeft;
            final pct = cap > 0 ? (reg / cap) : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.outline)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('$reg / $cap (${(pct * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: pct.clamp(0.0, 1.0), backgroundColor: AppColors.surfaceContainerLow, color: AppColors.primary),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 1. Students ──────────────────────────────────────────────────────────

  Widget _buildStudentsSection(BuildContext context, AppState state) {
    final list = state.studentsRoster;
    final filtered = list.where((s) {
      if (_studentSearch.trim().isEmpty) return true;
      final q = _studentSearch.toLowerCase();
      return s.name.toLowerCase().contains(q) || s.rollNumber.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _studentSearch = v),
            decoration: InputDecoration(
              hintText: 'Search ${state.studentsRoster.length} students by roll or name...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) {
              final s = filtered[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.outline)),
                child: Row(
                  children: [
                    CircleAvatar(child: Text(s.rollNumber.substring(s.rollNumber.length - 2))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${s.rollNumber} • ${s.academicDetails}'),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(s.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      backgroundColor: s.status == 'ACTIVE' ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── 2. Staff ─────────────────────────────────────────────────────────────

  Widget _buildStaffSection(BuildContext context, AppState state) {
    final staff = state.staffRoster;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: staff.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final st = staff[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.outline)),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: AppColors.primary, child: Text(st.name.isNotEmpty ? st.name[0] : 'F', style: const TextStyle(color: Colors.white))),
            title: Text(st.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${st.rollNumber} • ${st.academicDetails}\n${st.email} • Cabin: ${st.section}'),
          ),
        );
      },
    );
  }

  // ─── 3. Events ────────────────────────────────────────────────────────────

  Widget _buildEventsSection(BuildContext context, AppState state) {
    final events = state.events;
    if (events.isEmpty) {
      return const Center(child: Text('No events found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (ctx, i) {
        final e = events[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), overflow: TextOverflow.ellipsis),
                            ),
                            if (e.isTeamEvent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'TEAM (${e.minTeamSize}-${e.maxTeamSize})',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('${e.time} • ${e.venue}', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => state.deleteEvent(e.id),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(e.description, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Seats Left: ${e.seatsLeft} / ${e.totalSeats}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAdminEventRoster(ctx, state, e),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.people, size: 14),
                    label: Text(e.isTeamEvent ? 'Inspect Teams' : 'Inspect Roster', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAdminEventRoster(BuildContext context, AppState state, EventModel e) async {
    final roster = await state.fetchEventRegistrations(e.id);
    if (!context.mounted) return;

    final expandedTeams = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                          const SizedBox(height: 2),
                          Text(
                            e.isTeamEvent ? 'Admin Event Team Registrations' : 'Confirmed Individual Registrations',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${roster.length} Registrations',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppColors.outline),
                Expanded(
                  child: roster.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_outline, size: 40, color: AppColors.outlineVariant),
                              const SizedBox(height: 10),
                              Text('No registrations found for this event.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: roster.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (c, i) {
                            final r = roster[i];
                            final isExpanded = expandedTeams.contains(r.id);

                            if (r.isTeam) {
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.outline),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.groups, size: 20, color: AppColors.secondary),
                                            const SizedBox(width: 8),
                                            Text(
                                              r.teamName ?? 'Team Registration',
                                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            r.status,
                                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Leader: ${r.studentName} (${r.studentRoll})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary)),
                                    Text('Members: ${r.members.isNotEmpty ? r.members.length : 1}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            setSheetState(() {
                                              if (isExpanded) {
                                                expandedTeams.remove(r.id);
                                              } else {
                                                expandedTeams.add(r.id);
                                              }
                                            });
                                          },
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            side: const BorderSide(color: AppColors.outline),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16),
                                          label: Text(isExpanded ? 'Hide Members' : 'View Team', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                        ),
                                        Text('Status: ${r.status}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
                                      ],
                                    ),
                                    if (isExpanded) ...[
                                      const Divider(height: 16, color: AppColors.outline),
                                      Text('Members', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
                                      const SizedBox(height: 6),
                                      ...r.members.map((m) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 3),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.check, size: 14, color: Colors.green),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${m.studentName} (${m.studentRoll}) • ${m.studentDept} ${m.isLeader ? "(Leader)" : ""}',
                                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurface),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )),
                                    ],
                                  ],
                                ),
                              );
                            }

                            // Individual registration card
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.outline),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.secondaryContainer,
                                    child: Text(r.studentRoll.length > 2 ? r.studentRoll.substring(r.studentRoll.length - 2) : 'IT'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.studentName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.onSurface)),
                                        Text('${r.studentRoll} • ${r.studentDept}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      r.status,
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── 4. Polls ─────────────────────────────────────────────────────────────

  Widget _buildPollsSection(BuildContext context, AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: state.polls.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.outline)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              ...p.options.map((opt) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• ${opt.text}: ${opt.votes} votes', style: const TextStyle(fontSize: 12)),
              )),
            ],
          ),
        )).toList(),
      ),
    );
  }

  // ─── 5. Attendance ────────────────────────────────────────────────────────

  Widget _buildAttendanceSection(BuildContext context, AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outline)),
            child: Column(
              children: [
                const Text('Admin Gate Pass Verification', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _adminQrCtrl,
                  decoration: const InputDecoration(hintText: 'Enter student roll number (e.g. 24K61A1259)', isDense: true),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final val = _adminQrCtrl.text.trim();
                      if (val.isEmpty) return;
                      final res = await state.scanAndMarkAttendance(
                        qrOrRoll: val,
                        eventId: 'General Turnstile Gate Access',
                        session: 'Admin Console Gate #2',
                      );
                      setState(() {
                        _adminScanSuccess = res['success'] == true;
                        _adminScanFeedback = res['message'];
                        if (_adminScanSuccess) _adminQrCtrl.clear();
                      });
                    },
                    icon: const Icon(Icons.verified),
                    label: const Text('Verify & Punch Attendance'),
                  ),
                ),
                if (_adminScanFeedback != null) ...[
                  const SizedBox(height: 8),
                  Text(_adminScanFeedback!, style: TextStyle(color: _adminScanSuccess ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Recent Turnstile Scans', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...state.attendanceLogs.map((l) => ListTile(
            dense: true,
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(l.subject),
            subtitle: Text('${l.room} • ${l.time}'),
          )),
        ],
      ),
    );
  }

  // ─── 6. Reports ───────────────────────────────────────────────────────────

  Widget _buildReportsSection(BuildContext context, AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comprehensive Academic Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.outline)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall Department Attendance Rate: 92.4%', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('Active Student Accounts: 381 / 381 (100% Onboarded)'),
                Text('Total Events Scheduled: 7 Technical & Cultural'),
                Text('Average Gate Turnstile Clearance Latency: 120ms'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 7. Notifications ─────────────────────────────────────────────────────

  Widget _buildNotificationsSection(BuildContext context, AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: _notifTitleCtrl, decoration: const InputDecoration(labelText: 'Title', isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: _notifBodyCtrl, decoration: const InputDecoration(labelText: 'Message', isDense: true)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              if (_notifTitleCtrl.text.trim().isEmpty) return;
              await state.broadcastNotice(title: _notifTitleCtrl.text.trim(), message: _notifBodyCtrl.text.trim());
              _notifTitleCtrl.clear();
              _notifBodyCtrl.clear();
            },
            child: const Text('Broadcast Institutional Announcement'),
          ),
          const SizedBox(height: 16),
          ...state.notifications.map((n) => ListTile(title: Text(n.title), subtitle: Text(n.message))),
        ],
      ),
    );
  }

  // ─── 8. Settings ──────────────────────────────────────────────────────────

  Widget _buildSettingsSection(BuildContext context, AppState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_done, color: Colors.green),
          title: const Text('Supabase Backend Connection'),
          subtitle: Text(state.isSupabaseConnected ? 'Connected & Operational' : 'Offline'),
        ),
        const ListTile(
          leading: Icon(Icons.domain, color: AppColors.primary),
          title: Text('Configured Institutional Domain'),
          subtitle: Text('sasi.ac.in (Strict Enforcement)'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Sign Out of Admin Console', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          onTap: () {
            state.logout();
            context.go('/login');
          },
        ),
      ],
    );
  }

  Widget _kpiBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.outline)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
