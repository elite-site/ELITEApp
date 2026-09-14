import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';

class TeamRegistrationScreen extends StatefulWidget {
  final EventModel event;

  const TeamRegistrationScreen({super.key, required this.event});

  @override
  State<TeamRegistrationScreen> createState() => _TeamRegistrationScreenState();
}

class _TeamRegistrationScreenState extends State<TeamRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _teamNameCtrl = TextEditingController();
  late List<TeamMemberInfo> _members;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    // Current authenticated student is locked as the Team Leader
    _members = [
      TeamMemberInfo(
        studentId: user.id,
        studentRoll: user.rollNumber,
        studentName: user.name,
        studentEmail: user.email,
        studentDept: user.department,
        studentYear: user.yearLevel,
        isLeader: true,
      ),
    ];
  }

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    super.dispose();
  }

  void _openAddMemberDialog() {
    final state = context.read<AppState>();
    final maxSeats = widget.event.maxTeamSize;

    if (_members.length >= maxSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum team size of $maxSeats reached.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _AddMemberDialog(
        eventId: widget.event.id,
        currentMembers: _members,
        studentsRoster: state.studentsRoster,
        onMemberSelected: (newMember) {
          setState(() {
            _members.add(newMember);
            _errorMessage = null;
          });
        },
      ),
    );
  }

  void _removeMember(int index) {
    if (index == 0) return; // Cannot remove team leader
    setState(() {
      _members.removeAt(index);
    });
  }

  Future<void> _submitTeam() async {
    if (!_formKey.currentState!.validate()) return;

    if (_members.length < widget.event.minTeamSize) {
      setState(() {
        _errorMessage =
            'This event requires at least ${widget.event.minTeamSize} team members. Please add more members.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final state = context.read<AppState>();
    final result = await state.registerTeamEvent(
      eventId: widget.event.id,
      teamName: _teamNameCtrl.text.trim(),
      members: _members,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Team registered successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Team registration failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final leader = _members.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Team Registration',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.groups_outlined, color: AppColors.secondary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Team Size: ${event.minTeamSize} to ${event.maxTeamSize} Members • ${event.category}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Team Name Input
                Text(
                  'Team Name',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _teamNameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Team Alpha, ByteCrafters, CyberKnights',
                    prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter a team name';
                    }
                    if (v.trim().length < 3) {
                      return 'Team name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Team Leader Section (Auto-filled & Locked)
                Text(
                  'Team Leader (Current Student)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    leader.studentName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'LEADER',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${leader.studentRoll} • ${leader.studentDept} • ${leader.studentEmail}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.lock, size: 16, color: AppColors.onSurfaceVariant),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Team Members Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Team Members (${_members.length}/${event.maxTeamSize})',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (_members.length < event.maxTeamSize)
                      TextButton.icon(
                        onPressed: _openAddMemberDialog,
                        icon: const Icon(Icons.add, size: 16, color: AppColors.secondary),
                        label: Text(
                          '+ Add Member',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Member list
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _members.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final m = _members[i];
                    final isLeader = m.isLeader;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isLeader ? AppColors.secondary : AppColors.surfaceContainerHigh,
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isLeader ? Colors.white : AppColors.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.studentName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${m.studentRoll} • ${m.studentDept} • ${m.studentEmail}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLeader)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                              tooltip: 'Remove Member',
                              onPressed: () => _removeMember(i),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                // Minimum members hint if needed
                if (_members.length < event.minTeamSize)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Add at least ${event.minTeamSize - _members.length} more member(s) to meet requirements.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Error message banner if any
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitTeam,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.how_to_reg, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Register Team (${_members.length} Members)',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'All team members will automatically be marked as Registered.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  final String eventId;
  final List<TeamMemberInfo> currentMembers;
  final List<UserModel> studentsRoster;
  final ValueChanged<TeamMemberInfo> onMemberSelected;

  const _AddMemberDialog({
    required this.eventId,
    required this.currentMembers,
    required this.studentsRoster,
    required this.onMemberSelected,
  });

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final cleanQuery = _searchQuery.trim().toLowerCase();

    // Filter students roster by search query
    final matchingStudents = widget.studentsRoster.where((s) {
      if (cleanQuery.isEmpty) return true;
      return s.name.toLowerCase().contains(cleanQuery) ||
          s.rollNumber.toLowerCase().contains(cleanQuery) ||
          s.email.toLowerCase().contains(cleanQuery) ||
          s.department.toLowerCase().contains(cleanQuery);
    }).toList();

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Team Member',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Search registered college student by ID, Roll Number or Name',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: Column(
          children: [
            // Search Input
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search roll (e.g. 23CS042) or name...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Results list
            Expanded(
              child: matchingStudents.isEmpty
                  ? Center(
                      child: Text(
                        'No matching students found in @sasi.ac.in',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      itemCount: matchingStudents.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final student = matchingStudents[i];
                        final isAlreadyInThisTeam = widget.currentMembers
                            .any((m) => m.studentRoll.toLowerCase() == student.rollNumber.toLowerCase());
                        final isRegisteredForEvent =
                            state.isStudentRegisteredInAnyTeam(widget.eventId, student.rollNumber);

                        final bool cannotAdd = isAlreadyInThisTeam || isRegisteredForEvent;

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: cannotAdd ? AppColors.outline.withValues(alpha: 0.3) : AppColors.outline,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: cannotAdd ? Colors.grey : AppColors.primary,
                                child: Text(
                                  student.rollNumber.length >= 2
                                      ? student.rollNumber.substring(student.rollNumber.length - 2)
                                      : 'S',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: cannotAdd ? AppColors.onSurfaceVariant : AppColors.onSurface,
                                      ),
                                    ),
                                    Text(
                                      '${student.rollNumber} • ${student.department}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                    if (isAlreadyInThisTeam)
                                      Text(
                                        'Already added to this team',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.secondary,
                                        ),
                                      )
                                    else if (isRegisteredForEvent)
                                      Text(
                                        'Already registered for this event',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.error,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: cannotAdd
                                    ? null
                                    : () {
                                        final member = TeamMemberInfo(
                                          studentId: student.id,
                                          studentRoll: student.rollNumber,
                                          studentName: student.name,
                                          studentEmail: student.email,
                                          studentDept: student.department,
                                          studentYear: student.yearLevel,
                                          isLeader: false,
                                        );
                                        widget.onMemberSelected(member);
                                        Navigator.pop(ctx);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('+ Add'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
