import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../../state/app_state.dart';
import '../services/permission_service.dart';
import 'permission_dialog.dart';
import '../../ui/features/contacts/contacts_screen.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onNotificationTap;
  final String? title;
  final String? subtitle;

  const AppHeader({
    super.key,
    this.onNotificationTap,
    this.title,
    this.subtitle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;
    final permService = context.watch<PermissionService>();
    final hasPendingPerms = !permService.status.cameraGranted ||
        !permService.status.contactsGranted ||
        !permService.status.notificationsGranted;

    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.outline, height: 1),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppColors.outline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.account_balance,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? 'ELITE',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                subtitle ?? 'Information Technology',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [


        // Device Permissions Hub
        Stack(
          children: [
            IconButton(
              icon: Icon(
                hasPendingPerms ? Icons.security_update_warning_outlined : Icons.verified_user_outlined,
                size: 21,
                color: hasPendingPerms ? AppColors.secondary : AppColors.success,
              ),
              tooltip: 'Device Permissions Hub',
              onPressed: () => PermissionDialog.show(context),
            ),
            if (hasPendingPerms)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),

        // Department Contacts Directory
        IconButton(
          icon: const Icon(Icons.contacts_outlined, size: 20),
          tooltip: 'Department Contacts',
          color: AppColors.onSurface,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactsScreen()),
            );
          },
        ),

        // Institutional Role Badge (Read-Only)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: user.role == UserRole.admin
                ? AppColors.primary.withValues(alpha: 0.1)
                : (user.role == UserRole.staff
                    ? AppColors.primaryContainer.withValues(alpha: 0.15)
                    : AppColors.surfaceContainerLow),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: user.role == UserRole.admin
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                user.role == UserRole.student
                    ? Icons.school
                    : user.role == UserRole.staff
                        ? Icons.badge
                        : Icons.admin_panel_settings,
                size: 14,
                color: user.role == UserRole.admin ? AppColors.primary : AppColors.secondary,
              ),
              const SizedBox(width: 5),
              Text(
                user.role.name.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: user.role == UserRole.admin ? AppColors.primary : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),

        // Notification Bell
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined, size: 21),
              color: AppColors.onSurface,
              onPressed: onNotificationTap,
            ),
            if (state.unreadNotificationCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${state.unreadNotificationCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  factory StatusBadge.inProgress(String text) => StatusBadge(
        text: text,
        backgroundColor: const Color(0xFFFFDAD6),
        textColor: const Color(0xFF690007),
      );

  factory StatusBadge.queued(String text) => StatusBadge(
        text: text,
        backgroundColor: const Color(0xFFE2E8F0),
        textColor: const Color(0xFF334155),
      );

  factory StatusBadge.resolved(String text) => StatusBadge(
        text: text,
        backgroundColor: const Color(0xFFD1FAE5),
        textColor: const Color(0xFF065F46),
      );

  factory StatusBadge.active(String text) => StatusBadge(
        text: text,
        backgroundColor: AppColors.secondary,
        textColor: Colors.white,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: textColor,
        ),
      ),
    );
  }
}

class QrPassDialog extends StatelessWidget {
  final UserModel user;

  const QrPassDialog({super.key, required this.user});

  static void show(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => QrPassDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.qr_code_2, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OFFICIAL LAB PASS',
                          style: GoogleFonts.inter(
                            color: AppColors.secondaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          user.labPassRoom,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // QR code render
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outline, width: 1.5),
                    ),
                    child: QrImageView(
                      data: 'ELITE-IT://${user.labPassId}/${user.rollNumber}/${DateTime.now().millisecondsSinceEpoch}',
                      version: QrVersions.auto,
                      size: 190.0,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    user.labPassId,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '${user.name} • ${user.rollNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.outline),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16, color: AppColors.secondary),
                          const SizedBox(width: 6),
                          Text(
                            'Expires: ${user.labPassExpiry}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.successContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'AUTHORIZED',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Close Pass'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


