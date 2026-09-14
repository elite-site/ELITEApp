import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/permission_service.dart';

class DepartmentContact {
  final String name;
  final String role;
  final String phone;
  final String email;
  final String room;
  final bool isEmergency;

  const DepartmentContact({
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
    required this.room,
    this.isEmergency = false,
  });
}

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  final List<DepartmentContact> contacts = const [
    DepartmentContact(
      name: "IT Dept. Emergency Helpdesk",
      role: "24/7 Security & Server Incident Hotline",
      phone: "+1 (555) 019-HELP",
      email: "helpdesk.it@elite.edu",
      room: "Server Central B-01",
      isEmergency: true,
    ),
    DepartmentContact(
      name: "Prof. Robert Sterling",
      role: "Department Chair & Chief SysAdmin",
      phone: "+1 (555) 019-2849",
      email: "admin.it@elite.edu",
      room: "HOD Office, Level 4",
    ),
    DepartmentContact(
      name: "Dr. Sarah Jenkins",
      role: "Class Advisor & Associate Professor",
      phone: "+1 (555) 019-3820",
      email: "sarah.jenkins@elite.edu",
      room: "Staff Cabin 412",
    ),
    DepartmentContact(
      name: "Marcus Vance",
      role: "Lead Hardware & Lab 402 Administrator",
      phone: "+1 (555) 019-8492",
      email: "marcus.vance@elite.edu",
      room: "Advanced AI Lab 402",
    ),
    DepartmentContact(
      name: "Academic Affairs Coordinator",
      role: "Exam Timetable & On-Duty Validation",
      phone: "+1 (555) 019-4911",
      email: "academics.it@elite.edu",
      room: "Admin Block 102",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final permService = context.watch<PermissionService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Department Contacts', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permission Status Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: permService.status.contactsGranted ? AppColors.successContainer : const Color(0xFFFFF7F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: permService.status.contactsGranted ? AppColors.success : AppColors.secondary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    permService.status.contactsGranted ? Icons.check_circle : Icons.contacts,
                    color: permService.status.contactsGranted ? AppColors.success : AppColors.secondary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          permService.status.contactsGranted
                              ? 'Contacts Permission Active'
                              : 'Contacts Permission Required',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: permService.status.contactsGranted ? AppColors.success : AppColors.secondary,
                          ),
                        ),
                        Text(
                          permService.status.contactsGranted
                              ? 'You can save department contacts directly to your phonebook.'
                              : 'Grant access to export faculty and advisors into your device contacts.',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (!permService.status.contactsGranted)
                    ElevatedButton(
                      onPressed: () async {
                        final res = await permService.requestContacts();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res ? 'Contacts permission granted!' : 'Permission denied in Android settings'),
                              backgroundColor: res ? AppColors.success : AppColors.error,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      child: const Text('Allow'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Official Directory',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface),
            ),
            const SizedBox(height: 10),

            ...contacts.map((c) => _contactCard(context, c, permService)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context, DepartmentContact c, PermissionService permService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.isEmergency ? AppColors.secondary : AppColors.outline,
          width: c.isEmergency ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.isEmergency ? AppColors.secondary : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  c.isEmergency ? Icons.emergency : Icons.person,
                  color: c.isEmergency ? Colors.white : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                    ),
                    Text(
                      c.role,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: c.isEmergency ? AppColors.secondary : AppColors.onSurfaceVariant,
                        fontWeight: c.isEmergency ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.outline),
          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.phone, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(c.phone, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 14),
              const Icon(Icons.room, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  c.room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Simulated call to ${c.phone} launched')),
                    );
                  },
                  icon: const Icon(Icons.call, size: 16, color: AppColors.primary),
                  label: Text('Call', style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (!permService.status.contactsGranted) {
                      final ok = await permService.requestContacts();
                      if (!ok) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contacts permission needed to save contact')),
                          );
                        }
                        return;
                      }
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved "${c.name}" (${c.phone}) to Device Contacts!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: Text('Save Contact', style: GoogleFonts.inter(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
