import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/app_state.dart';
import 'team_registration_screen.dart';
import 'project_submission_screen.dart';
import 'project_showcase_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _searchQuery = '';
  bool _showMyRegistrationsOnly = false;

  final List<String> _categories = ["All", "Workshops", "Hackathons", "Tech Talks"];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    List<EventModel> displayedEvents = state.filteredEvents;

    if (_showMyRegistrationsOnly) {
      displayedEvents = displayedEvents.where((e) => e.isRegistered).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      displayedEvents = displayedEvents
          .where((e) =>
              e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              e.speaker.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              e.venue.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return Scaffold(
      appBar: const AppHeader(),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search events, workshops, speakers...',
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.onSurfaceVariant),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // My Registrations Toggle
                    FilterChip(
                      selected: _showMyRegistrationsOnly,
                      label: Text(
                        'Registered (${state.registeredEvents.length})',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _showMyRegistrationsOnly ? Colors.white : AppColors.onSurface,
                        ),
                      ),
                      selectedColor: AppColors.secondary,
                      backgroundColor: AppColors.surfaceContainerLow,
                      showCheckmark: false,
                      side: BorderSide.none,
                      onSelected: (val) => setState(() => _showMyRegistrationsOnly = val),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Category Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = state.selectedEventCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.onSurface,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceContainerLow,
                          showCheckmark: false,
                          side: BorderSide.none,
                          onSelected: (_) => state.setEventCategory(cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.outline),

          // Department Events Header Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.surfaceContainerLow,
            child: Row(
              children: [
                const Icon(Icons.bolt, size: 14, color: AppColors.secondary),
                const SizedBox(width: 6),
                Text(
                  'Department Live Events & Workshops',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  ' Available',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),

          // Events List with RefreshIndicator
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => state.syncFromSupabase(),
              color: const Color(0xFF3ECF8E),
              child: displayedEvents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 48, color: AppColors.outlineVariant),
                          const SizedBox(height: 12),
                          Text(
                            _showMyRegistrationsOnly
                                ? 'No registered events yet'
                                : 'No matching events found',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: displayedEvents.length,
                      itemBuilder: (ctx, i) => _buildEventCard(context, displayedEvents[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, EventModel event) {
    final state = context.watch<AppState>();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: event.isRegistered ? AppColors.secondary.withValues(alpha: 0.5) : AppColors.outline,
          width: event.isRegistered ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Card Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Block
                Container(
                  width: 52,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        event.dateMonth,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        event.dateDay,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Details
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final isReg = state.isStudentRegisteredForEvent(event.id);
                      final reg = state.getRegistrationForEvent(event.id);
                      final isTeamReg = reg?.isTeam == true;
                      final isLeader = reg?.isLeader(state.currentUser.rollNumber) == true;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  event.category.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (event.isTeamEvent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'TEAM (${event.minTeamSize}-${event.maxTeamSize})',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              if (isReg)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check, size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        isTeamReg
                                            ? (isLeader ? 'TEAM LEADER' : 'TEAM MEMBER')
                                            : 'CONFIRMED',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                    const SizedBox(height: 6),
                    Text(
                      event.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),

    // Metadata Row: Speaker & Venue
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
      child: Row(
        children: [
          const Icon(Icons.mic, size: 14, color: AppColors.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              event.speaker,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.location_on, size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              event.venue.split('&').first.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),

    // Footer Action Bar
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Builder(
        builder: (context) {
          final isReg = state.isStudentRegisteredForEvent(event.id);
          final reg = state.getRegistrationForEvent(event.id);
          final isTeamReg = reg?.isTeam == true;
          final isLeader = reg?.isLeader(state.currentUser.rollNumber) == true;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 15, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        '${event.seatsLeft} seats left',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: event.seatsLeft < 10 ? AppColors.error : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _showEventDetailsModal(context, event),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.outline),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Details',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                    ),
                  ),
                  if (event.isProjectSubmissionEnabled && isReg) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectSubmissionScreen(event: event),
                          ),
                        );
                      },
                      icon: const Icon(Icons.code, size: 14),
                      label: Text(
                        'Project',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                  if (event.isVotingEnabled || event.isProjectSubmissionEnabled) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectShowcaseScreen(event: event),
                          ),
                        );
                      },
                      icon: const Icon(Icons.how_to_vote, size: 14),
                      label: Text(
                        event.isVotingEnabled ? 'Vote' : 'Showcase',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                  ElevatedButton(
                    onPressed: () {
                      if (isReg) {
                        _showEventDetailsModal(context, event);
                      } else if (event.isTeamEvent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamRegistrationScreen(event: event),
                          ),
                        );
                      } else {
                        _showIndividualRegistrationDialog(context, event);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isReg
                          ? AppColors.surfaceContainerHigh
                          : (event.isTeamEvent ? AppColors.secondary : AppColors.primary),
                      foregroundColor: isReg ? AppColors.onSurface : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      isReg
                          ? (isTeamReg ? (isLeader ? 'Team (Leader)' : 'Team Member') : 'Registered')
                          : (event.isTeamEvent ? 'Register Team' : 'Register'),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  ],
),
);
}

  void _showEventDetailsModal(BuildContext context, EventModel event) {
    final state = context.read<AppState>();
    final user = state.currentUser;
    final isReg = state.isStudentRegisteredForEvent(event.id);
    final reg = state.getRegistrationForEvent(event.id);
    final isTeamReg = reg?.isTeam == true;
    final isLeader = reg?.isLeader(user.rollNumber) == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.category.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (event.isTeamEvent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'TEAM (${event.minTeamSize}-${event.maxTeamSize})',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${event.seatsLeft} of ${event.totalSeats} open',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.title,
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.onSurface),
              ),
              const SizedBox(height: 16),
              _detailRow(Icons.calendar_today, '${event.dateMonth} ${event.dateDay}, 2026 • ${event.time}'),
              const SizedBox(height: 8),
              _detailRow(Icons.location_on, event.venue),
              const SizedBox(height: 8),
              _detailRow(Icons.person, event.speaker),
              const SizedBox(height: 16),

              // If registered as team member or leader: Display Team Card
              if (isReg && isTeamReg && reg != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.groups, color: AppColors.secondary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    reg.teamName ?? 'Team Registration',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isLeader ? 'TEAM LEADER' : 'REGISTERED MEMBER',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Team Leader: ${reg.studentName} (${reg.studentRoll})',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Registered Team Roster:',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...reg.members.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${m.studentName} (${m.studentRoll}) • ${m.studentDept} ${m.isLeader ? '★ Leader' : ''}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified, size: 14, color: AppColors.success),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Individual attendance can be scanned for each member.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (isReg) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Individual Registration Confirmed',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              '${user.name} • ${user.rollNumber} • ${user.department}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Divider(color: AppColors.outline),
              const SizedBox(height: 12),
              Text(
                'About this Event',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                event.description,
                style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Text(
                'Guidelines & Checklist',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface),
              ),
              const SizedBox(height: 6),
              _checklistRow('Department WiFi & lab environments prepared'),
              _checklistRow('Official college ID required at seminar hall gate'),
              _checklistRow('Valid Lab Pass or Student digital QR code active'),
              const SizedBox(height: 24),

              // Action Buttons
              if (isReg) ...[
                if (event.isProjectSubmissionEnabled) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectSubmissionScreen(event: event),
                          ),
                        );
                      },
                      icon: const Icon(Icons.code, size: 18),
                      label: Text(
                        'Submit / Edit Project',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (event.isVotingEnabled || event.isProjectSubmissionEnabled) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectShowcaseScreen(event: event),
                          ),
                        );
                      },
                      icon: const Icon(Icons.how_to_vote, size: 18),
                      label: Text(
                        event.isVotingEnabled ? 'Project Showcase & Vote' : 'View Project Showcase',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: null, // Locked as registered
                    icon: const Icon(Icons.verified, size: 16),
                    label: Text(
                      isTeamReg
                          ? (isLeader ? 'Registered as Team Leader' : 'Registered as Team Member')
                          : 'Registered (Pass Confirmed)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerHigh,
                      foregroundColor: AppColors.onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (!isTeamReg || isLeader)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        context.read<AppState>().cancelEventRegistration(event.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Registration cancelled')),
                        );
                      },
                      child: Text(
                        isTeamReg ? 'Disband Team & Cancel Registration' : 'Cancel Registration',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ] else ...[
                if (event.isVotingEnabled || event.isProjectSubmissionEnabled) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectShowcaseScreen(event: event),
                          ),
                        );
                      },
                      icon: const Icon(Icons.how_to_vote, size: 18),
                      label: Text(
                        event.isVotingEnabled ? 'Browse Projects & Vote' : 'Browse Submitted Projects',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (event.isTeamEvent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamRegistrationScreen(event: event),
                          ),
                        );
                      } else {
                        _showIndividualRegistrationDialog(context, event);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: event.isTeamEvent ? AppColors.secondary : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      event.isTeamEvent
                          ? 'Register Team (${event.minTeamSize}-${event.maxTeamSize} Members)'
                          : 'Confirm Registration & Pre-fill Profile',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showIndividualRegistrationDialog(BuildContext context, EventModel event) {
    final state = context.read<AppState>();
    final user = state.currentUser;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Individual Registration',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              event.title,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Auto-filled from authenticated profile:',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  _profileItem('Student Name', user.name),
                  _profileItem('Roll Number', user.rollNumber),
                  _profileItem('College Email', user.email),
                  _profileItem('Department', user.department),
                  _profileItem('Academic Year', user.academicDetails),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.verified, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pre-filled verified credentials via @sasi.ac.in',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await state.registerIndividualEvent(eventId: event.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Registered!'),
                    backgroundColor: res['success'] == true ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm Registration'),
          ),
        ],
      ),
    );
  }

  Widget _profileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurface),
          ),
        ),
      ],
    );
  }

  Widget _checklistRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}




