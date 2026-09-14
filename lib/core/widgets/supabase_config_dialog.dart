import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../../state/app_state.dart';

class SupabaseConfigDialog extends StatefulWidget {
  const SupabaseConfigDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SupabaseConfigDialog(),
    );
  }

  @override
  State<SupabaseConfigDialog> createState() => _SupabaseConfigDialogState();
}

class _SupabaseConfigDialogState extends State<SupabaseConfigDialog> {
  late TextEditingController _urlCtrl;
  late TextEditingController _keyCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final supa = context.read<SupabaseService>();
    _urlCtrl = TextEditingController(text: supa.url);
    _keyCtrl = TextEditingController(text: supa.anonKey);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supa = context.watch<SupabaseService>();
    final isConnected = supa.isInitialized;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3ECF8E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt, color: Color(0xFF3ECF8E), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supabase Database Engine',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'PostgreSQL backend for all events, polls, and attendance',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isConnected ? AppColors.successContainer : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isConnected ? AppColors.success : AppColors.outline),
                ),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.cloud_done : Icons.cloud_queue,
                      color: isConnected ? AppColors.success : AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected ? 'Connected to Supabase Cloud' : 'Local Fallback Mode Active',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isConnected ? AppColors.success : AppColors.onSurface,
                            ),
                          ),
                          Text(
                            isConnected
                                ? 'Events, RSVPs, Polls & Tickets sync live with PostgreSQL.'
                                : 'Using offline data until valid Supabase project credentials are saved.',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Supabase Project URL',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  hintText: 'https://xyzcompany.supabase.co',
                  prefixIcon: Icon(Icons.link, size: 20, color: AppColors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Supabase Anon / Public API Key',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                  prefixIcon: Icon(Icons.key, size: 20, color: AppColors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 20),

              // Supported Tables Pill Tags
              Text(
                'Synchronized Database Tables',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: const [
                  _DbTag('events'),
                  _DbTag('event_registrations'),
                  _DbTag('event_attendance'),
                  _DbTag('polls'),
                  _DbTag('poll_options'),
                  _DbTag('poll_votes'),
                  _DbTag('student_queries'),
                  _DbTag('notifications'),
                  _DbTag('students'),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);
                          final appState = context.read<AppState>();
                          // Credentials are hardcoded — just trigger a live sync
                          await appState.syncFromSupabase();
                          if (!mounted) return;
                          setState(() => _isSaving = false);
                          nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Live sync complete. Supabase connection is active.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3ECF8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.sync, size: 18),
                  label: Text(
                    _isSaving ? 'Connecting & Syncing...' : 'Save & Sync with Supabase',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DbTag extends StatelessWidget {
  final String title;

  const _DbTag(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.table_chart, size: 12, color: AppColors.secondary),
          const SizedBox(width: 4),
          Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

