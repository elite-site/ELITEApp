import '../../core/widgets/permission_dialog.dart';
import '../features/contacts/contacts_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/app_state.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;

    return Scaffold(
      appBar: const AppHeader(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student ID Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.school, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ELITE IT DEPARTMENT',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user.role.name.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Roll No: ${user.rollNumber}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _idMetric('YEAR', user.yearLevel),
                      _idMetric('SECTION', user.section),
                      _idMetric('DEPT', 'IT'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Academic Credentials Card
            Text(
              'Academic Credentials',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  _infoTile('Department', user.department, Icons.domain),
                  const Divider(height: 1, color: AppColors.outline),
                  _infoTile('Year & Section', '${user.yearLevel} • Section ${user.section}', Icons.class_outlined),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Settings & Preferences
            Text(
              'Security & App Settings',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  _switchTile('Push Notifications for Event Alerts', true, Icons.notifications_active_outlined),
                  const Divider(height: 1, color: AppColors.outline),
                  _actionTile(context, 'Department Contacts Directory', Icons.contacts_outlined, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen()));
                  }),
                  const Divider(height: 1, color: AppColors.outline),
                  _actionTile(context, 'Device Permissions Hub (Camera, Contacts, Alerts)', Icons.security, onTap: () {
                    PermissionDialog.show(context);
                  }),
                  const Divider(height: 1, color: AppColors.outline),
                  _actionTile(context, 'Change Account Password', Icons.lock_outline),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out / Switch User Buttons
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<AppState>().logout();
                  context.go('/login');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.secondary),
                  foregroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: Text(
                  'Sign Out of Session',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _idMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _infoTile(String title, String subtitle, IconData icon) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: AppColors.secondary, size: 20),
      title: Text(title, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface),
      ),
    );
  }

  Widget _switchTile(String title, bool value, IconData icon) {
    return StatefulBuilder(
      builder: (ctx, setTileState) => SwitchListTile(
        dense: true,
        secondary: Icon(icon, color: AppColors.secondary, size: 20),
        title: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        value: value,
        activeTrackColor: AppColors.secondary,
        onChanged: (val) {
          setTileState(() => value = val);
        },
      ),
    );
  }

  Widget _actionTile(BuildContext context, String title, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: AppColors.secondary, size: 20),
      title: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.onSurfaceVariant),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Security credential manager opened')),
        );
      },
    );
  }
}





