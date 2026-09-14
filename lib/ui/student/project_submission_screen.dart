import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';

class ProjectSubmissionScreen extends StatefulWidget {
  final EventModel event;
  final Map<String, dynamic>? teamInfo;

  const ProjectSubmissionScreen({
    super.key,
    required this.event,
    this.teamInfo,
  });

  @override
  State<ProjectSubmissionScreen> createState() => _ProjectSubmissionScreenState();
}

class _ProjectSubmissionScreenState extends State<ProjectSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _projectNameCtrl;
  late TextEditingController _shortDescCtrl;
  late TextEditingController _detailedDescCtrl;
  late TextEditingController _techCtrl;
  late TextEditingController _repoUrlCtrl;
  late TextEditingController _demoUrlCtrl;
  late TextEditingController _docUrlCtrl;
  late TextEditingController _presUrlCtrl;
  late TextEditingController _imageUrlCtrl;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _submissionId;
  String _submissionStatus = 'PENDING';
  String? _errorMessage;

  bool get isLocked {
    final deadline = widget.event.projectSubmissionDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _projectNameCtrl = TextEditingController();
    _shortDescCtrl = TextEditingController();
    _detailedDescCtrl = TextEditingController();
    _techCtrl = TextEditingController();
    _repoUrlCtrl = TextEditingController();
    _demoUrlCtrl = TextEditingController();
    _docUrlCtrl = TextEditingController();
    _presUrlCtrl = TextEditingController();
    _imageUrlCtrl = TextEditingController();

    _loadExistingSubmission();
  }

  @override
  void dispose() {
    _projectNameCtrl.dispose();
    _shortDescCtrl.dispose();
    _detailedDescCtrl.dispose();
    _techCtrl.dispose();
    _repoUrlCtrl.dispose();
    _demoUrlCtrl.dispose();
    _docUrlCtrl.dispose();
    _presUrlCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingSubmission() async {
    final state = context.read<AppState>();
    final reg = state.getRegistrationForEvent(widget.event.id);
    final regId = widget.teamInfo?['registrationId']?.toString() ?? reg?.id ?? '';

    try {
      final existing = await state.getTeamProjectSubmission(widget.event.id, regId);
      if (existing != null && mounted) {
        setState(() {
          _submissionId = existing.id;
          _submissionStatus = existing.status;
          _projectNameCtrl.text = existing.projectName;
          _shortDescCtrl.text = existing.shortDescription;
          _detailedDescCtrl.text = existing.detailedDescription;
          _techCtrl.text = existing.technologies.join(', ');
          _repoUrlCtrl.text = existing.repoUrl ?? '';
          _demoUrlCtrl.text = existing.demoUrl ?? '';
          _docUrlCtrl.text = existing.documentationUrl ?? '';
          _presUrlCtrl.text = existing.presentationUrl ?? '';
          _imageUrlCtrl.text = existing.imageUrl ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading project submission: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSubmission() async {
    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submission Locked: The deadline has passed. Changes cannot be saved.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final state = context.read<AppState>();
    final reg = state.getRegistrationForEvent(widget.event.id);
    final regId = widget.teamInfo?['registrationId']?.toString() ?? reg?.id ?? '';
    final leaderId = state.currentUser.id;
    final leaderName = widget.teamInfo?['leaderName']?.toString() ?? reg?.studentName ?? state.currentUser.name;
    final teamName = widget.teamInfo?['teamName']?.toString() ?? reg?.teamName ?? 'Team ${state.currentUser.name}';

    final id = _submissionId ?? 'proj_${widget.event.id}_$regId';

    final techList = _techCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final project = ProjectSubmissionModel(
      id: id,
      eventId: widget.event.id,
      registrationId: regId,
      teamName: teamName,
      leaderId: leaderId,
      leaderName: leaderName,
      projectName: _projectNameCtrl.text.trim(),
      shortDescription: _shortDescCtrl.text.trim(),
      detailedDescription: _detailedDescCtrl.text.trim(),
      technologies: techList,
      repoUrl: _repoUrlCtrl.text.trim().isNotEmpty ? _repoUrlCtrl.text.trim() : null,
      demoUrl: _demoUrlCtrl.text.trim().isNotEmpty ? _demoUrlCtrl.text.trim() : null,
      documentationUrl: _docUrlCtrl.text.trim().isNotEmpty ? _docUrlCtrl.text.trim() : null,
      presentationUrl: _presUrlCtrl.text.trim().isNotEmpty ? _presUrlCtrl.text.trim() : null,
      imageUrl: _imageUrlCtrl.text.trim().isNotEmpty ? _imageUrlCtrl.text.trim() : null,
      status: _submissionStatus,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    final res = await state.submitTeamProject(project);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Project submitted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Failed to submit project.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadline = widget.event.projectSubmissionDeadline;
    final deadlineStr = deadline != null
        ? DateFormat('d MMMM yyyy, h:mm a').format(deadline)
        : '15 September 2026, 6:00 PM';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Project Submission',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team Info Badge
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.groups, color: AppColors.secondary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.teamInfo?['teamName'] ?? 'Your Team',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Event: ${widget.event.title} • Role: ${widget.teamInfo?['role'] ?? 'Participant'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_submissionStatus == 'PUBLISHED')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PUBLISHED',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Deadline Notice
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isLocked
                            ? const Color(0xFFFEF2F2)
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLocked ? const Color(0xFFFECACA) : AppColors.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isLocked ? Icons.lock : Icons.timer_outlined,
                            size: 16,
                            color: isLocked ? const Color(0xFFDC2626) : AppColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isLocked
                                  ? 'Submission Locked: The deadline ($deadlineStr) has passed.'
                                  : 'Submission Deadline: $deadlineStr',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isLocked ? const Color(0xFFDC2626) : AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDC2626)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Project Name
                    _buildLabel('Project Title *'),
                    TextFormField(
                      controller: _projectNameCtrl,
                      enabled: !isLocked,
                      decoration: _inputDecoration('e.g. Smart Campus Navigation System'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Project title is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Short Description
                    _buildLabel('Short Summary / Abstract *'),
                    TextFormField(
                      controller: _shortDescCtrl,
                      enabled: !isLocked,
                      maxLines: 2,
                      decoration: _inputDecoration('A concise 1-2 sentence pitch of your project...'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Short summary is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Detailed Description
                    _buildLabel('Detailed Description & Architecture'),
                    TextFormField(
                      controller: _detailedDescCtrl,
                      enabled: !isLocked,
                      maxLines: 4,
                      decoration: _inputDecoration('Problem statement, system design, outcomes...'),
                    ),
                    const SizedBox(height: 16),

                    // Technologies
                    _buildLabel('Technologies Used (comma separated)'),
                    TextFormField(
                      controller: _techCtrl,
                      enabled: !isLocked,
                      decoration: _inputDecoration('e.g. Flutter, Supabase, Python, OpenCV'),
                    ),
                    const SizedBox(height: 16),

                    // Repository URL
                    _buildLabel('Code Repository URL'),
                    TextFormField(
                      controller: _repoUrlCtrl,
                      enabled: !isLocked,
                      decoration: _inputDecoration('https://github.com/username/project'),
                    ),
                    const SizedBox(height: 16),

                    // Demo / Live URL
                    _buildLabel('Live Demo / Video URL'),
                    TextFormField(
                      controller: _demoUrlCtrl,
                      enabled: !isLocked,
                      decoration: _inputDecoration('https://demo.project.com or YouTube link'),
                    ),
                    const SizedBox(height: 16),

                    // Documentation URL
                    _buildLabel('Documentation / Paper URL (Optional)'),
                    TextFormField(
                      controller: _docUrlCtrl,
                      enabled: !isLocked,
                      decoration: _inputDecoration('https://drive.google.com/... or Notion link'),
                    ),
                    const SizedBox(height: 16),

                    // Project Image / Banner URL
                    _buildLabel('Project Image URL / Banner URL'),
                    TextFormField(
                      controller: _imageUrlCtrl,
                      enabled: !isLocked,
                      decoration: _inputDecoration('https://... image link or Supabase asset URL'),
                      onChanged: (_) => setState(() {}),
                    ),

                    if (_imageUrlCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _imageUrlCtrl.text.trim(),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 80,
                            color: AppColors.surfaceContainerLow,
                            alignment: Alignment.center,
                            child: const Text('Invalid image URL preview', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLocked || _isSaving ? null : _saveSubmission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                isLocked
                                    ? 'Submission Locked'
                                    : (_submissionId != null ? 'Update Project' : 'Submit Project'),
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
      ),
    );
  }
}
