import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/app_state.dart';

class StaffDashboardScreen extends StatefulWidget {
  final int initialTab;
  final Function(int)? onTabChanged;

  const StaffDashboardScreen({
    super.key,
    this.initialTab = 0,
    this.onTabChanged,
  });

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  // Manual attendance input for scanner
  final TextEditingController _qrInputController = TextEditingController();
  String _selectedEventForScan = "ev_vibe_coding";
  String _selectedSessionForScan = "IT Lab 4";
  String? _scanFeedbackMessage;
  bool _isScanSuccess = false;

  // Search & filters
  String _studentSearchQuery = '';
  String _selectedYearFilter = 'All';

  // Broadcast Notice Form
  final TextEditingController _notifTitleController = TextEditingController();
  final TextEditingController _notifMsgController = TextEditingController();
  String _notifCategory = 'Urgent';

  @override
  void dispose() {
    _qrInputController.dispose();
    _notifTitleController.dispose();
    _notifMsgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;

    return Scaffold(
      appBar: AppHeader(
        title: 'STAFF PORTAL',
        subtitle: 'Faculty Event Administration',
        onNotificationTap: () => widget.onTabChanged?.call(5),
      ),
      body: RefreshIndicator(
        onRefresh: () => state.syncFromSupabase(),
        child: _buildCurrentTab(context, state, user),
      ),
    );
  }

  Widget _buildCurrentTab(BuildContext context, AppState state, UserModel user) {
    switch (widget.initialTab) {
      case 0:
        return _buildHomeTab(context, state, user);
      case 1:
        return _buildEventsTab(context, state);
      case 2:
        return _buildStudentsTab(context, state);
      case 3:
        return _buildAttendanceTab(context, state);
      case 4:
        return _buildPollsTab(context, state);
      case 5:
        return _buildNotificationsTab(context, state);
      case 6:
        return _buildProfileTab(context, state, user);
      default:
        return _buildHomeTab(context, state, user);
    }
  }

  // ─── 1. Home Tab ──────────────────────────────────────────────────────────

  Widget _buildHomeTab(BuildContext context, AppState state, UserModel user) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Faculty Welcome Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.badge, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'FACULTY COORDINATOR',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user.rollNumber,
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        user.academicDetails,
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick Action Launchers
          Row(
            children: [
              Expanded(
                child: _quickTile(
                  icon: Icons.qr_code_scanner,
                  color: AppColors.secondary,
                  label: 'Scan QR Attendance',
                  onTap: () => widget.onTabChanged?.call(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickTile(
                  icon: Icons.add_circle_outline,
                  color: AppColors.primary,
                  label: 'Create Event',
                  onTap: () => _showCreateEventModal(context, state),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickTile(
                  icon: Icons.campaign_outlined,
                  color: AppColors.error,
                  label: 'Send Alert',
                  onTap: () => widget.onTabChanged?.call(5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Department Announcements
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Department Announcements',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface),
              ),
              TextButton(
                onPressed: () => widget.onTabChanged?.call(5),
                child: Text('View All', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...state.notifications.take(3).map((n) => _noticeCard(n)),
          const SizedBox(height: 24),

          // Active Events Overview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Department Events Lineup',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface),
              ),
              TextButton(
                onPressed: () => widget.onTabChanged?.call(1),
                child: Text('Manage Events', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...state.events.take(3).map((e) => _staffEventSnippet(context, state, e)),
        ],
      ),
    );
  }

  // ─── 2. Events Management Tab ─────────────────────────────────────────────

  Widget _buildEventsTab(BuildContext context, AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EVENT MANAGEMENT',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.onSurfaceVariant),
                  ),
                  Text(
                    'College Events & Workshops',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateEventModal(context, state),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Event'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ...state.events.map((e) => _fullStaffEventCard(context, state, e)),
        ],
      ),
    );
  }

  // ─── 3. Students Tab ──────────────────────────────────────────────────────

  Widget _buildStudentsTab(BuildContext context, AppState state) {
    final students = state.studentsRoster;
    final filtered = students.where((s) {
      if (_selectedYearFilter != 'All' && !s.yearLevel.contains(_selectedYearFilter)) return false;
      if (_studentSearchQuery.trim().isNotEmpty) {
        final q = _studentSearchQuery.toLowerCase();
        return s.name.toLowerCase().contains(q) || s.rollNumber.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _studentSearchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by Roll No or Student Name...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.onSurfaceVariant),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', '1st Year', '2nd Year', '3rd Year', '4th Year'].map((yr) {
                    final isSel = _selectedYearFilter == yr;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(yr),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSel ? Colors.white : AppColors.onSurfaceVariant,
                        ),
                        onSelected: (_) => setState(() => _selectedYearFilter = yr),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final s = filtered[idx];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.secondaryContainer,
                      child: Text(s.rollNumber.length > 2 ? s.rollNumber.substring(s.rollNumber.length - 2) : 'IT',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.onSurface)),
                          Text('${s.rollNumber} • ${s.academicDetails}',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
                          Text(s.email, style: GoogleFonts.inter(fontSize: 10, color: AppColors.secondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.status == 'ACTIVE' ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        s.status,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: s.status == 'ACTIVE' ? Colors.green : Colors.red),
                      ),
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

  // ─── 4. QR Attendance Scanner (Staff & Admin Only) ────────────────────────

  Widget _buildAttendanceTab(BuildContext context, AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Restricted Staff Scanner: Scans student digital QR pass and validates against Supabase attendance bus.',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Scanner Target Configuration
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scan Target & Location', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedEventForScan,
                  decoration: const InputDecoration(
                    labelText: 'Target Event / Class',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: state.events.map((e) => DropdownMenuItem(value: e.id, child: Text(e.title))).toList(),
                  onChanged: (v) => setState(() => _selectedEventForScan = v ?? _selectedEventForScan),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSessionForScan,
                  decoration: const InputDecoration(
                    labelText: 'Turnstile Gate / Hall',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Turnstile Gate #2', child: Text('Turnstile Gate #2 (Main)')),
                    DropdownMenuItem(value: 'IT Lab 4', child: Text('IT Lab 4')),
                    DropdownMenuItem(value: 'AIML Seminar Hall', child: Text('AIML Seminar Hall')),
                  ],
                  onChanged: (v) => setState(() => _selectedSessionForScan = v ?? _selectedSessionForScan),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Interactive Scan / Punch Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: AppColors.secondary, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  'Scan Student QR Pass or Enter Roll No',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  'e.g. 24K61A1259 or ELITE_QR_24K61A1259',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _qrInputController,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Enter Roll Number / Token',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _qrInputController.clear(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _handleScanSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.verified, size: 18),
                    label: Text('Verify & Mark Attendance', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ),

                // Visual Feedback Banner
                if (_scanFeedbackMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isScanSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _isScanSuccess ? Colors.green : Colors.red),
                    ),
                    child: Row(
                      children: [
                        Icon(_isScanSuccess ? Icons.check_circle : Icons.error, color: _isScanSuccess ? Colors.green : Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _scanFeedbackMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isScanSuccess ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recent Scans
          Text('Recent Scans Logged', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...state.attendanceLogs.take(5).map((l) => _attendanceLogCard(l)),
        ],
      ),
    );
  }

  void _handleScanSubmit() async {
    final query = _qrInputController.text.trim();
    if (query.isEmpty) return;

    final state = context.read<AppState>();
    final res = await state.scanAndMarkAttendance(
      qrOrRoll: query,
      eventId: _selectedEventForScan,
      session: _selectedSessionForScan,
    );

    setState(() {
      _isScanSuccess = res['success'] == true;
      _scanFeedbackMessage = res['message'];
      if (_isScanSuccess) {
        _qrInputController.clear();
      }
    });
  }

  // ─── 5. Polls Tab (Staff Conducts; CANNOT Vote) ───────────────────────────

  Widget _buildPollsTab(BuildContext context, AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GOVERNANCE POLLS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.onSurfaceVariant)),
                  Text('Department Polls', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreatePollModal(context, state),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Poll'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Strict restriction notice: Staff cannot vote
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade900, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Staff Policy: Staff coordinators conduct and oversee student polls. Voting participation is restricted to students.',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ...state.polls.map((p) => _staffPollCard(context, state, p)),
        ],
      ),
    );
  }

  // ─── 6. Notifications Tab ─────────────────────────────────────────────────

  Widget _buildNotificationsTab(BuildContext context, AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BROADCAST ALERTS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.onSurfaceVariant)),
          Text('Send Department Notices', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
          const SizedBox(height: 14),

          // Notice Composer Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dispatch Push Notification', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 12),
                TextField(
                  controller: _notifTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Headline / Title',
                    hintText: 'e.g. Lab 4 Maintenance Rescheduled',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notifMsgController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notice Message',
                    hintText: 'Enter full notice text for students...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _notifCategory,
                  decoration: const InputDecoration(labelText: 'Category', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'Urgent', child: Text('Urgent / Immediate Alert')),
                    DropdownMenuItem(value: 'Academic', child: Text('Academic')),
                    DropdownMenuItem(value: 'System', child: Text('System / Infrastructure')),
                  ],
                  onChanged: (v) => setState(() => _notifCategory = v ?? 'Urgent'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (_notifTitleController.text.trim().isEmpty) return;
                      await state.broadcastNotice(
                        title: _notifTitleController.text.trim(),
                        message: _notifMsgController.text.trim(),
                        category: _notifCategory,
                      );
                      _notifTitleController.clear();
                      _notifMsgController.clear();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notice broadcasted to Supabase!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.send, size: 16),
                    label: Text('Broadcast to All Students', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Recent Dispatched Notices', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...state.notifications.map((n) => _noticeCard(n)),
        ],
      ),
    );
  }

  // ─── 7. Profile Tab ───────────────────────────────────────────────────────

  Widget _buildProfileTab(BuildContext context, AppState state, UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary,
                  child: Text(user.name.isNotEmpty ? user.name[0] : 'F', style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Text(user.name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(user.email, style: GoogleFonts.inter(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${user.department} • ${user.academicDetails}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.badge_outlined, color: AppColors.primary),
                  title: const Text('Faculty Employee ID'),
                  subtitle: Text(user.rollNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.meeting_room_outlined, color: AppColors.primary),
                  title: const Text('Department Cabin'),
                  subtitle: Text(user.section.isNotEmpty ? user.section : 'IT Department Staff Room'),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.domain, color: AppColors.primary),
                  title: const Text('Verified College Domain'),
                  subtitle: const Text('sasi.ac.in (Institutional Authority)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                state.logout();
                context.go('/login');
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.logout),
              label: Text('Sign Out of Faculty Portal', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helper Widgets & Modals ──────────────────────────────────────────────

  Widget _quickTile({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _noticeCard(AppNotification n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: n.category == 'Urgent' ? AppColors.error.withValues(alpha: 0.12) : AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(n.category, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: n.category == 'Urgent' ? AppColors.error : AppColors.secondary)),
              ),
              Text(n.timeAgo, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          Text(n.title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Text(n.message, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _staffEventSnippet(BuildContext context, AppState state, EventModel e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                Text('${e.time} • ${e.venue}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showEventRoster(context, state, e),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerLow,
              foregroundColor: AppColors.onSurface,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Roster', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _fullStaffEventCard(BuildContext context, AppState state, EventModel e) {
    final cap = e.totalSeats;
    final registered = cap - e.seatsLeft;
    final pct = cap > 0 ? (registered / cap) : 0.0;

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(e.category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
              Text('$registered / $cap Registered', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(e.title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(e.description, style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0), backgroundColor: AppColors.surfaceContainerLow, color: AppColors.secondary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showEventRoster(context, state, e),
                icon: const Icon(Icons.list_alt, size: 16),
                label: const Text('Registered Roster'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                onPressed: () => state.deleteEvent(e.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _staffPollCard(BuildContext context, AppState state, PollModel p) {
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
              Text(p.category, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('${p.totalVotes} Total Student Votes', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(p.question, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          ...p.options.map((opt) {
            final pct = p.totalVotes > 0 ? (opt.votes / p.totalVotes) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(opt.text, style: GoogleFonts.inter(fontSize: 12)),
                      Text('${opt.votes} (${(pct * 100).toStringAsFixed(0)}%)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: pct, backgroundColor: AppColors.surfaceContainerLow, color: AppColors.primary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _attendanceLogCard(AttendanceLog l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(l.subject, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
          Text('${l.room} • ${l.time}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  // Modals for Create Event, Create Poll, Roster
  void _showCreateEventModal(BuildContext context, AppState state) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final venueCtrl = TextEditingController(text: "IT Lab 4");
    final rulesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create New Event', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Event Title', isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: venueCtrl, decoration: const InputDecoration(labelText: 'Venue / Lab', isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: rulesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Rules & Guidelines', isDense: true)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    await state.createEvent(
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      category: 'Technical',
                      venue: venueCtrl.text.trim(),
                      eventDate: DateTime.now().toIso8601String().split('T').first,
                      startTime: '10:00 AM',
                      endTime: '04:00 PM',
                      maxCapacity: 100,
                      facultyCoordinators: state.currentUser.name,
                      rules: rulesCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Publish Event to Supabase'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePollModal(BuildContext context, AppState state) {
    final qCtrl = TextEditingController();
    final opt1Ctrl = TextEditingController();
    final opt2Ctrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Initiate Department Poll', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: qCtrl, decoration: const InputDecoration(labelText: 'Question', isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: opt1Ctrl, decoration: const InputDecoration(labelText: 'Option 1', isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: opt2Ctrl, decoration: const InputDecoration(labelText: 'Option 2', isDense: true)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () async {
                  if (qCtrl.text.trim().isEmpty || opt1Ctrl.text.trim().isEmpty || opt2Ctrl.text.trim().isEmpty) return;
                  await state.createPoll(
                    question: qCtrl.text.trim(),
                    description: 'Departmental Student Ballot',
                    category: 'Department',
                    options: [opt1Ctrl.text.trim(), opt2Ctrl.text.trim()],
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Launch Poll'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showEventRoster(BuildContext context, AppState state, EventModel e) async {
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
                            e.isTeamEvent ? 'Team Registrations & Member Rosters' : 'Individual Registrations Roster',
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
                        '${roster.length} ${e.isTeamEvent ? "Teams" : "Students"}',
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
                              Text('No registrations found for this event yet.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
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
                                        Text(
                                          'Status: ${r.status}',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
                                        ),
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
                                                IconButton(
                                                  icon: const Icon(Icons.qr_code_scanner, size: 16, color: AppColors.primary),
                                                  tooltip: 'Punch Attendance',
                                                  onPressed: () {
                                                    _qrInputController.text = m.studentRoll;
                                                    _selectedEventForScan = e.id;
                                                    Navigator.pop(ctx);
                                                    widget.onTabChanged?.call(3); // Switch to attendance tab
                                                  },
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
}
