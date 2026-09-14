import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';

class ProjectShowcaseScreen extends StatefulWidget {
  final EventModel event;

  const ProjectShowcaseScreen({super.key, required this.event});

  @override
  State<ProjectShowcaseScreen> createState() => _ProjectShowcaseScreenState();
}

class _ProjectShowcaseScreenState extends State<ProjectShowcaseScreen> {
  List<ProjectSubmissionModel> _projects = [];
  bool _isLoading = true;
  bool _hasVoted = false;
  String? _votedProjectId;
  bool _isVoting = false;

  bool get isVotingActive {
    if (!widget.event.isVotingEnabled) return false;
    final now = DateTime.now();
    if (widget.event.votingStart != null && now.isBefore(widget.event.votingStart!)) {
      return false;
    }
    if (widget.event.votingEnd != null && now.isAfter(widget.event.votingEnd!)) {
      return false;
    }
    return true;
  }

  String get votingStatusMessage {
    if (!widget.event.isVotingEnabled) return 'Voting is not enabled for this event.';
    final now = DateTime.now();
    if (widget.event.votingStart != null && now.isBefore(widget.event.votingStart!)) {
      return 'Voting has not started yet.';
    }
    if (widget.event.votingEnd != null && now.isAfter(widget.event.votingEnd!)) {
      return 'Voting has ended.';
    }
    return 'Voting is live • Cast your official ballot';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final state = context.read<AppState>();
    setState(() => _isLoading = true);

    try {
      final projs = await state.getPublishedProjects(widget.event.id);
      final voted = await state.hasVotedInEvent(widget.event.id);

      if (mounted) {
        setState(() {
          _projects = projs;
          _hasVoted = voted;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading project showcase: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmAndVote(ProjectSubmissionModel project) async {
    if (_hasVoted) return;

    final state = context.read<AppState>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Confirm Vote',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Vote for "${project.projectName}" by ${project.teamName}?\n\nEach participant can vote only once. You cannot change your vote after submitting.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Vote'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isVoting = true);
    final result = await state.castProjectVote(widget.event.id, project.id);

    if (!mounted) return;
    setState(() => _isVoting = false);

    if (result['success'] == true) {
      setState(() {
        _hasVoted = true;
        _votedProjectId = project.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Vote Recorded'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Unable to record vote'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Project Showcase & Voting',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Voting Status Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _hasVoted
                            ? const Color(0xFFECFDF5)
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _hasVoted ? const Color(0xFFA7F3D0) : AppColors.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hasVoted
                                ? Icons.check_circle
                                : (isVotingActive ? Icons.how_to_vote : Icons.info_outline),
                            size: 18,
                            color: _hasVoted
                                ? const Color(0xFF047857)
                                : (isVotingActive ? AppColors.secondary : AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _hasVoted
                                      ? '✓ Vote Recorded'
                                      : (isVotingActive ? 'Voting Live' : 'Voting Closed'),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _hasVoted
                                        ? const Color(0xFF047857)
                                        : AppColors.onSurface,
                                  ),
                                ),
                                Text(
                                  _hasVoted
                                      ? 'Your vote has been recorded. You cannot change your vote.'
                                      : votingStatusMessage,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: _hasVoted
                                        ? const Color(0xFF065F46)
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'PUBLISHED PROJECTS (${_projects.length})',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_projects.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Text(
                          'No published projects yet.\nProjects approved by coordinators will appear here.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                        ),
                      )
                    else
                      ..._projects.map((proj) => _projectCard(proj)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _projectCard(ProjectSubmissionModel project) {
    final isThisProjectVoted = _votedProjectId == project.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isThisProjectVoted ? AppColors.secondary : AppColors.outline,
          width: isThisProjectVoted ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Image Banner (if available)
          if (project.imageUrl != null && project.imageUrl!.trim().isNotEmpty)
            Image.network(
              project.imageUrl!.trim(),
              height: 170,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team & Leader Header (Respects Privacy: Leader name only, NO member emails/IDs)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          project.teamName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Leader: ${project.leaderName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Project Title
                Text(
                  project.projectName,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),

                // Short Description
                Text(
                  project.shortDescription,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),

                if (project.detailedDescription.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    project.detailedDescription,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.85),
                    ),
                  ),
                ],

                // Technologies Pills
                if (project.technologies.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: project.technologies.map((tech) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tech,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Resource Links (Repo, Demo, Docs)
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (project.repoUrl != null && project.repoUrl!.isNotEmpty)
                      _linkChip(Icons.code, 'Repository', project.repoUrl!),
                    if (project.demoUrl != null && project.demoUrl!.isNotEmpty)
                      _linkChip(Icons.play_circle_outline, 'Live Demo', project.demoUrl!),
                    if (project.documentationUrl != null && project.documentationUrl!.isNotEmpty)
                      _linkChip(Icons.description_outlined, 'Docs', project.documentationUrl!),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Voting Action Button
                // CRITICAL REQUIREMENT: Students NEVER see vote counts, percentages, or leaderboards.
                if (_hasVoted)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isThisProjectVoted
                          ? const Color(0xFFECFDF5)
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isThisProjectVoted ? '✓ You Voted For This Project' : 'Vote Recorded',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isThisProjectVoted
                            ? const Color(0xFF047857)
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: isVotingActive && !_isVoting
                          ? () => _confirmAndVote(project)
                          : null,
                      icon: const Icon(Icons.how_to_vote_outlined, size: 16),
                      label: Text(
                        isVotingActive ? 'Vote for Project' : 'Voting Unavailable',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkChip(IconData icon, String label, String url) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.secondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}
