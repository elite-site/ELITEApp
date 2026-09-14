import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/permission_service.dart';

class PermissionDialog extends StatelessWidget {
  const PermissionDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PermissionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permService = context.watch<PermissionService>();
    final status = permService.status;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
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
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.security, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ELITE Permissions Hub',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'Required permissions for full department automation',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Camera
          _permissionItem(
            context,
            icon: Icons.camera_alt_outlined,
            title: 'Camera Access',
            description: 'Required to scan turnstile QR codes and lab equipment tags.',
            isGranted: status.cameraGranted,
            onRequest: () async {
              final granted = await permService.requestCamera();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(granted ? 'Camera permission granted!' : 'Camera permission denied'),
                    backgroundColor: granted ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
          ),
          const Divider(height: 1, color: AppColors.outline),

          // 2. Internet
          _permissionItem(
            context,
            icon: Icons.wifi,
            title: 'Internet & Network',
            description: 'Required for real-time cloud sync, exam timetables, and alerts.',
            isGranted: status.internetActive,
            isStatic: true,
            onRequest: () {},
          ),
          const Divider(height: 1, color: AppColors.outline),

          // 3. Contacts
          _permissionItem(
            context,
            icon: Icons.contacts_outlined,
            title: 'Contacts Access',
            description: 'Required to sync faculty advisors and departmental emergency contacts.',
            isGranted: status.contactsGranted,
            onRequest: () async {
              final granted = await permService.requestContacts();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(granted ? 'Contacts permission granted!' : 'Contacts permission denied'),
                    backgroundColor: granted ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
          ),
          const Divider(height: 1, color: AppColors.outline),

          // 4. Notifications
          _permissionItem(
            context,
            icon: Icons.notifications_active_outlined,
            title: 'Push Notifications',
            description: 'Required for emergency turnstile broadcasts and event schedules.',
            isGranted: status.notificationsGranted,
            onRequest: () async {
              final granted = await permService.requestNotifications();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(granted ? 'Notification permission granted!' : 'Notification permission denied'),
                    backgroundColor: granted ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // Grant All Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await permService.requestAllPermissions();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All permissions requested successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.verified_user, size: 18),
              label: Text(
                'Grant All Permissions',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _permissionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
    bool isStatic = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted ? AppColors.successContainer : AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isGranted ? AppColors.success : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isStatic || isGranted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ACTIVE',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success),
              ),
            )
          else
            OutlinedButton(
              onPressed: onRequest,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: AppColors.secondary),
                foregroundColor: AppColors.secondary,
              ),
              child: Text(
                'Allow',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
