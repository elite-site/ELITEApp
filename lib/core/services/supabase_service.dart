import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../../data/models/app_models.dart';

class SupabaseService extends ChangeNotifier {
  static String _url = SupabaseConfig.url;
  static String _anonKey = SupabaseConfig.anonKey;
  static bool _isInitialized = false;

  String get url => _url;
  String get anonKey => _anonKey;
  bool get isInitialized => _isInitialized;
  bool get isConfigured => SupabaseConfig.isConfigured;

  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    _url = SupabaseConfig.url.trim();
    _anonKey = SupabaseConfig.anonKey.trim();

    if (!isConfigured) {
      debugPrint('SupabaseService: SupabaseConfig.isConfigured is false.');
      _isInitialized = false;
      notifyListeners();
      return;
    }

    try {
      await Supabase.initialize(
        url: _url,
        // ignore: deprecated_member_use
        anonKey: _anonKey,
        debug: kDebugMode,
      );
      _isInitialized = true;
      debugPrint('SupabaseService: Successfully initialized and connected to $_url');
    } catch (e) {
      debugPrint('SupabaseService.init error: $e');
      _isInitialized = false;
    }
    notifyListeners();
  }

  RealtimeChannel? _realtimeChannel;

  void subscribeToRealtimeChanges(VoidCallback onTableChanged) {
    final c = client;
    if (c == null) return;
    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = c.channel('public_live_sync')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          callback: (payload) {
            debugPrint('⚡ Supabase Realtime event in Flutter: ${payload.table}');
            onTableChanged();
          },
        )
        ..subscribe();
    } catch (e) {
      debugPrint('Error subscribing to Supabase Realtime: $e');
    }
  }


  // ─── User Profile & Role Resolution ─────────────────────────────────────────

  Future<UserModel?> fetchUserByCredentials({
    required String username,
    required String password,
  }) async {
    final c = client;
    if (c == null) return null;

    final u = username.trim();
    final p = password.trim();

    try {
      // 1. Resolve email address for Supabase Auth
      String targetEmail = u;
      if (!u.contains('@')) {
        // Look up profile by roll_number or id
        final profileRes = await c
            .from('profiles')
            .select('id, email, roll_number')
            .or('roll_number.ilike.$u,id.eq.$u')
            .maybeSingle();

        if (profileRes != null && profileRes['email'] != null && profileRes['email'].toString().isNotEmpty) {
          targetEmail = profileRes['email'].toString();
        } else {
          targetEmail = '${u.toLowerCase()}@sasi.ac.in';
        }
      }

      // 2. Authoritative authentication via Supabase Auth
      try {
        final authRes = await c.auth.signInWithPassword(
          email: targetEmail,
          password: p,
        );

        if (authRes.user != null) {
          return await fetchUserProfileById(authRes.user!.id);
        }
      } catch (authErr) {
        debugPrint('Supabase Auth signIn error: $authErr');
        // Secondary attempt with default email pattern if user entered raw roll number
        if (!u.contains('@') && targetEmail != '${u.toLowerCase()}@sasi.ac.in') {
          try {
            final fallbackAuth = await c.auth.signInWithPassword(
              email: '${u.toLowerCase()}@sasi.ac.in',
              password: p,
            );
            if (fallbackAuth.user != null) {
              return await fetchUserProfileById(fallbackAuth.user!.id);
            }
          } catch (_) {}
        }
      }

      return null;
    } catch (e) {
      debugPrint('SupabaseService.fetchUserByCredentials error: $e');
      return null;
    }
  }

  Future<UserModel?> fetchUserProfileById(String userId) async {
    final c = client;
    if (c == null) return null;
    try {
      final res = await c
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        return _mapProfileRowToUser(res);
      }
    } catch (e) {
      debugPrint('SupabaseService.fetchUserProfileById error: $e');
    }
    return null;
  }

  Future<UserModel?> fetchUserProfile(String identifier) async {
    final c = client;
    if (c == null) return null;

    final q = identifier.trim();
    if (q.isEmpty) return null;

    try {
      // Authoritative lookup on profiles table (id, email, or roll_number)
      final res = await c
          .from('profiles')
          .select()
          .or('id.eq.$q,email.ilike.$q,roll_number.ilike.$q')
          .maybeSingle();

      if (res != null) {
        return _mapProfileRowToUser(res);
      }
    } catch (e) {
      debugPrint('SupabaseService.fetchUserProfile error: $e');
    }
    return null;
  }

  UserModel _mapProfileRowToUser(Map<String, dynamic> row) {
    final roleStr = (row['role'] ?? 'student').toString().trim().toLowerCase();
    final userRole = roleStr == 'admin'
        ? UserRole.admin
        : (roleStr == 'staff' ? UserRole.staff : UserRole.student);

    final roll = row['roll_number']?.toString() ?? '';
    final name = row['full_name']?.toString() ?? 'User';
    final dept = row['department']?.toString() ?? 'Information Technology';
    final yr = row['year']?.toString() ?? (userRole == UserRole.student ? '3rd Year' : 'Faculty');
    final sec = row['section']?.toString() ?? 'A';
    final isActive = row['is_active'] != false;

    return UserModel(
      id: row['id']?.toString() ?? '',
      name: name,
      email: row['email']?.toString() ?? '',
      rollNumber: roll,
      role: userRole,
      department: dept,
      academicDetails: userRole == UserRole.student ? 'B.Tech IT • $yr' : 'Department Faculty',
      yearLevel: yr,
      section: sec,
      phoneNumber: row['phone']?.toString() ?? '',
      status: isActive ? 'ACTIVE' : 'INACTIVE',
      labPassId: roll.isNotEmpty ? 'PASS-$roll' : 'ELITE_QR_PASS',
      labPassRoom: 'IT Lab & Turnstile Gate #2',
      labPassExpiry: 'AY 2026-2027',
      cgpa: userRole == UserRole.student ? 8.94 : 0.0,
      attendancePercent: 90,
    );
  }

  // ─── Events (CRUD for Staff/Admin, View & Register for Students) ──────────

  Future<List<EventModel>> fetchEvents() async {
    final c = client;
    if (c == null) return [];

    try {
      final res = await c
          .from('events')
          .select()
          .order('event_date', ascending: true);

      final List<EventModel> list = [];
      for (var row in res) {
        final dateStr = (row['event_date'] ?? '2026-10-24').toString();
        final parts = dateStr.split('-');
        String month = "OCT";
        String day = "24";
        if (parts.length >= 3) {
          final mInt = int.tryParse(parts[1]) ?? 10;
          const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
          month = months[(mInt - 1).clamp(0, 11)];
          day = parts[2];
        }

        final eventType = (row['event_type'] ?? 'individual').toString().toLowerCase();
        final isTeam = eventType == 'team';
        final isProjEnabled = row['submission_enabled'] == true;
        final projDeadline = row['submission_deadline'] != null
            ? DateTime.tryParse(row['submission_deadline'].toString())
            : null;

        final isVoteEnabled = row['voting_enabled'] == true;
        final vStart = row['voting_start'] != null ? DateTime.tryParse(row['voting_start'].toString()) : null;
        final vEnd = row['voting_end'] != null ? DateTime.tryParse(row['voting_end'].toString()) : null;
        List<String> vRoles = ['student', 'staff'];
        if (row['voting_eligible_roles'] is List) {
          vRoles = (row['voting_eligible_roles'] as List).map((e) => e.toString()).toList();
        }

        final statusStr = (row['status'] ?? 'published').toString().toUpperCase();

        list.add(EventModel(
          id: row['id'].toString(),
          title: row['title'] ?? 'Department Event',
          description: row['description'] ?? '',
          category: row['category'] ?? (isTeam ? 'Hackathon' : 'Technical'),
          dateMonth: month,
          dateDay: day,
          time: '${row['start_time'] ?? '10:00:00'} - ${row['end_time'] ?? '17:00:00'}',
          venue: row['venue'] ?? 'Campus Auditorium',
          speaker: 'Faculty & Student Coordinators',
          seatsLeft: 500,
          totalSeats: 500,
          isRegistered: false,
          rules: row['instructions']?.toString() ?? row['rules_pdf_url']?.toString() ?? '',
          status: statusStr == 'PUBLISHED' ? 'OPEN' : statusStr,
          isTeamEvent: isTeam,
          minTeamSize: isTeam ? 2 : 1,
          maxTeamSize: isTeam ? 4 : 1,
          isProjectSubmissionEnabled: isProjEnabled,
          projectSubmissionDeadline: projDeadline,
          isVotingEnabled: isVoteEnabled,
          votingStart: vStart,
          votingEnd: vEnd,
          votingEligibleRoles: vRoles,
        ));
      }
      return list;
    } catch (e) {
      debugPrint('Supabase fetchEvents error: $e');
      return [];
    }
  }

  Future<bool> createEvent({
    required String title,
    required String description,
    required String category,
    required String venue,
    required String eventDate,
    required String startTime,
    required String endTime,
    int maxCapacity = 500,
    String facultyCoordinators = '',
    String rules = '',
    bool isTeam = false,
  }) async {
    final c = client;
    if (c == null) return false;

    try {
      await c.from('events').insert({
        'title': title,
        'description': description,
        'category': category,
        'event_type': isTeam ? 'team' : 'individual',
        'venue': venue,
        'event_date': eventDate,
        'start_time': startTime,
        'end_time': endTime,
        'instructions': rules,
        'registration_enabled': true,
        'status': 'published',
      });
      return true;
    } catch (e) {
      debugPrint('SupabaseService.createEvent error: $e');
      return false;
    }
  }

  Future<bool> updateEvent(String eventId, Map<String, dynamic> updates) async {
    final c = client;
    if (c == null) return false;

    try {
      await c.from('events').update(updates).eq('id', eventId);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.updateEvent error: $e');
      return false;
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    final c = client;
    if (c == null) return false;

    try {
      await c.from('events').delete().eq('id', eventId);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.deleteEvent error: $e');
      return false;
    }
  }

  Future<List<EventRegistrationModel>> fetchEventRegistrations(String eventId) async {
    final c = client;
    if (c == null) return [];

    try {
      final res = await c
          .from('event_registrations')
          .select('id, event_id, student_id, team_id, registration_status, registered_at, profiles!inner(id, full_name, roll_number, email, department, year), teams(id, team_name)')
          .eq('event_id', eventId)
          .order('registered_at', ascending: false);

      final List<EventRegistrationModel> list = [];
      for (final r in res) {
        final profile = r['profiles'] as Map<String, dynamic>? ?? {};
        final team = r['teams'] as Map<String, dynamic>?;
        final teamId = r['team_id']?.toString();
        final isTeam = teamId != null && teamId.isNotEmpty;

        List<TeamMemberInfo> memberList = [];
        if (isTeam) {
          try {
            final membersRes = await c
                .from('team_members')
                .select('student_id, is_leader, profiles(id, full_name, roll_number, email, department, year)')
                .eq('team_id', teamId);

            for (final m in membersRes) {
              final mProf = m['profiles'] as Map<String, dynamic>? ?? {};
              memberList.add(TeamMemberInfo(
                studentId: m['student_id']?.toString() ?? '',
                studentRoll: mProf['roll_number']?.toString() ?? '',
                studentName: mProf['full_name']?.toString() ?? '',
                studentEmail: mProf['email']?.toString() ?? '',
                studentDept: mProf['department']?.toString() ?? 'IT',
                studentYear: mProf['year']?.toString() ?? '3rd Year',
                isLeader: m['is_leader'] == true,
              ));
            }
          } catch (_) {}
        }

        list.add(EventRegistrationModel(
          id: r['id']?.toString() ?? '',
          eventId: r['event_id']?.toString() ?? eventId,
          isTeam: isTeam,
          teamName: team?['team_name']?.toString(),
          studentId: r['student_id']?.toString() ?? '',
          studentRoll: profile['roll_number']?.toString() ?? '',
          studentName: profile['full_name']?.toString() ?? 'Student',
          studentEmail: profile['email']?.toString() ?? '',
          studentYear: profile['year']?.toString() ?? '3rd Year',
          members: memberList,
          status: (r['registration_status'] ?? 'confirmed').toString().toUpperCase(),
          registeredAt: r['registered_at']?.toString() ?? '',
        ));
      }
      return list;
    } catch (e) {
      debugPrint('SupabaseService.fetchEventRegistrations error: $e');
      return [];
    }
  }

  Future<bool> registerEvent({
    required String eventId,
    required UserModel user,
  }) async {
    final c = client;
    if (c == null) return false;

    try {
      await c.from('event_registrations').insert({
        'event_id': eventId,
        'student_id': user.id,
        'team_id': null,
        'registration_status': 'confirmed',
      });
      return true;
    } catch (e) {
      debugPrint('Supabase registerEvent error: $e');
      return false;
    }
  }

  Future<bool> registerTeam({
    required String eventId,
    required String teamName,
    required UserModel leader,
    required List<TeamMemberInfo> members,
  }) async {
    final c = client;
    if (c == null) return false;

    try {
      // 1. Create team row
      final teamRes = await c.from('teams').insert({
        'event_id': eventId,
        'team_name': teamName,
        'leader_id': leader.id,
      }).select('id').single();

      final teamId = teamRes['id'].toString();

      // 2. Resolve member IDs if necessary
      final List<Map<String, dynamic>> resolvedMembers = [];
      for (final m in members) {
        String resolvedId = m.studentId;
        final isUuid = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(resolvedId);
        if (!isUuid) {
          final prof = await c
              .from('profiles')
              .select('id')
              .or('roll_number.ilike.${m.studentRoll},email.ilike.${m.studentEmail}')
              .maybeSingle();
          if (prof != null) {
            resolvedId = prof['id'].toString();
          }
        }
        if (resolvedId.isNotEmpty) {
          resolvedMembers.add({
            'student_id': resolvedId,
            'is_leader': (resolvedId == leader.id) || m.isLeader,
          });
        }
      }

      // 3. Insert team members
      final memberRows = resolvedMembers.map((m) => {
        'team_id': teamId,
        'student_id': m['student_id'],
        'is_leader': m['is_leader'],
      }).toList();

      await c.from('team_members').insert(memberRows);

      // 4. Insert event_registrations for each member
      final regRows = resolvedMembers.map((m) => {
        'event_id': eventId,
        'student_id': m['student_id'],
        'team_id': teamId,
        'registration_status': 'confirmed',
      }).toList();

      await c.from('event_registrations').insert(regRows);

      return true;
    } catch (e) {
      debugPrint('Supabase registerTeam error: $e');
      return false;
    }
  }

  Future<bool> cancelRegistration({
    required String eventId,
    required String userId,
  }) async {
    final c = client;
    if (c == null) return false;

    try {
      await c
          .from('event_registrations')
          .delete()
          .eq('event_id', eventId)
          .eq('student_id', userId);
      return true;
    } catch (e) {
      debugPrint('Supabase cancelRegistration error: $e');
      return false;
    }
  }

  Future<List<String>> fetchUserRegisteredEventIds(String userId, {String? rollNumber}) async {
    final c = client;
    if (c == null) return [];

    try {
      final res = await c
          .from('event_registrations')
          .select('event_id')
          .eq('student_id', userId);

      final List<String> list = (res as List)
          .map((r) => r['event_id'].toString())
          .toList();
      return list;
    } catch (e) {
      debugPrint('Supabase fetchUserRegisteredEventIds error: $e');
      return [];
    }
  }

  // ─── Team Registration Details Lookup ───────────────────────────────────────

  Future<Map<String, dynamic>?> fetchTeamRegistrationForUser(
    String eventId,
    String userId, {
    String? rollNumber,
  }) async {
    final c = client;
    if (c == null) return null;

    try {
      final regRes = await c
          .from('event_registrations')
          .select('id, event_id, student_id, team_id, registration_status, teams(id, team_name, leader_id)')
          .eq('event_id', eventId)
          .eq('student_id', userId)
          .maybeSingle();

      if (regRes == null) return null;

      final teamId = regRes['team_id']?.toString();
      final isTeam = teamId != null && teamId.isNotEmpty;
      final teamData = regRes['teams'] as Map<String, dynamic>?;

      if (!isTeam || teamData == null) {
        return {
          'registrationId': regRes['id']?.toString() ?? '',
          'teamName': 'Individual',
          'isLeader': true,
          'role': 'Participant',
          'leaderName': 'Self',
          'leaderRoll': rollNumber ?? '',
          'membersCount': 1,
          'isTeam': false,
        };
      }

      final leaderId = teamData['leader_id']?.toString() ?? '';
      final isLeader = leaderId == userId;

      int membersCount = 1;
      String leaderName = 'Leader';
      String leaderRoll = '';

      try {
        final membersRes = await c.from('team_members').select('student_id').eq('team_id', teamId);
        membersCount = (membersRes as List).length;

        final leaderProf = await c.from('profiles').select('full_name, roll_number').eq('id', leaderId).maybeSingle();
        if (leaderProf != null) {
          leaderName = leaderProf['full_name']?.toString() ?? leaderName;
          leaderRoll = leaderProf['roll_number']?.toString() ?? leaderRoll;
        }
      } catch (_) {}

      return {
        'registrationId': regRes['id']?.toString() ?? '',
        'teamId': teamId,
        'teamName': teamData['team_name']?.toString() ?? 'Team',
        'isLeader': isLeader,
        'role': isLeader ? 'Team Leader' : 'Team Member',
        'leaderName': leaderName,
        'leaderRoll': leaderRoll,
        'membersCount': membersCount,
        'isTeam': true,
      };
    } catch (e) {
      debugPrint('Supabase fetchTeamRegistrationForUser error: $e');
      return null;
    }
  }

  // ─── Project Submission & Image Upload ──────────────────────────────────────

  Future<ProjectSubmissionModel?> fetchTeamProjectSubmission(
    String eventId,
    String registrationId,
  ) async {
    final c = client;
    if (c == null) return null;

    try {
      final isUuid = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(registrationId);
      if (!isUuid) return null;

      final res = await c
          .from('project_submissions')
          .select()
          .eq('event_id', eventId)
          .or('team_id.eq.$registrationId,id.eq.$registrationId,submitted_by.eq.$registrationId')
          .maybeSingle();

      if (res != null) {
        return ProjectSubmissionModel.fromJson(res);
      }
      return null;
    } catch (e) {
      debugPrint('Supabase fetchTeamProjectSubmission error: $e');
      return null;
    }
  }

  Future<List<ProjectSubmissionModel>> fetchPublishedProjects(String eventId) async {
    final c = client;
    if (c == null) return [];

    try {
      final res = await c
          .from('project_submissions')
          .select()
          .eq('event_id', eventId)
          .eq('is_published', true)
          .order('submitted_at', ascending: false);

      return (res as List)
          .map((item) => ProjectSubmissionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Supabase fetchPublishedProjects error: $e');
      return [];
    }
  }

  Future<String?> uploadProjectImage(
    Uint8List imageBytes,
    String fileExtension, {
    String? fileName,
  }) async {
    final c = client;
    if (c == null) return null;

    try {
      final ext = fileExtension.replaceAll('.', '').toLowerCase();
      final name = fileName ?? 'proj_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'submissions/$name';

      await c.storage.from('project-images').uploadBinary(
        path,
        imageBytes,
        fileOptions: FileOptions(
          contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
          upsert: true,
        ),
      );

      final publicUrl = c.storage.from('project-images').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Supabase uploadProjectImage error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> submitProjectSubmission(ProjectSubmissionModel project) async {
    final c = client;
    if (c == null) {
      return {'success': false, 'message': 'Supabase client is not connected'};
    }

    try {
      final isTeamUuid = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(project.registrationId);

      final data = <String, dynamic>{
        'event_id': project.eventId,
        'team_id': isTeamUuid ? project.registrationId : null,
        'submitted_by': project.leaderId,
        'project_title': project.projectName,
        'description': project.shortDescription.isNotEmpty ? project.shortDescription : project.detailedDescription,
        'technologies': project.technologies,
        'github_url': project.repoUrl,
        'live_demo_url': project.demoUrl,
        'documentation_url': project.documentationUrl,
        'ppt_url': project.presentationUrl,
        'status': 'submitted',
      };

      if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(project.id)) {
        data['id'] = project.id;
      }

      final res = await c.from('project_submissions').upsert(data).select().single();

      if (project.imageUrl != null && project.imageUrl!.isNotEmpty) {
        final submissionId = res['id']?.toString() ?? project.id;
        try {
          await c.from('project_images').insert({
            'project_submission_id': submissionId,
            'storage_path': project.imageUrl!,
            'public_url': project.imageUrl!,
          });
        } catch (_) {}
      }

      return {'success': true, 'message': 'Project submitted successfully!'};
    } catch (e) {
      final msg = e.toString();
      debugPrint('Supabase submitProjectSubmission error: $e');
      if (msg.toLowerCase().contains('deadline') || msg.toLowerCase().contains('locked')) {
        return {
          'success': false,
          'message': 'Submission Locked: The deadline has passed. Changes cannot be saved.',
        };
      }
      return {'success': false, 'message': 'Error saving project: $e'};
    }
  }

  // ─── Project Voting (One User = One Vote) ───────────────────────────────────

  Future<bool> hasUserVotedForEvent(String eventId, String voterId) async {
    final c = client;
    if (c == null) return false;

    try {
      final poll = await c.from('polls').select('id').eq('event_id', eventId).maybeSingle();
      if (poll == null) return false;

      final res = await c
          .from('poll_votes')
          .select('id')
          .eq('poll_id', poll['id'])
          .eq('voter_id', voterId)
          .maybeSingle();

      return res != null;
    } catch (e) {
      debugPrint('Supabase hasUserVotedForEvent error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> castProjectVote({
    required String eventId,
    required String projectId,
    required String voterId,
    required String voterRole,
  }) async {
    final c = client;
    if (c == null) {
      return {'success': false, 'message': 'Supabase client is not connected'};
    }

    try {
      final poll = await c.from('polls').select('id').eq('event_id', eventId).maybeSingle();
      if (poll == null) {
        return {'success': false, 'message': 'Voting is not active for this event.'};
      }
      final pollId = poll['id'].toString();

      final opt = await c
          .from('poll_options')
          .select('id')
          .eq('poll_id', pollId)
          .eq('project_submission_id', projectId)
          .maybeSingle();

      if (opt == null) {
        return {'success': false, 'message': 'Project voting option not found.'};
      }
      final optId = opt['id'].toString();

      await c.from('poll_votes').insert({
        'poll_id': pollId,
        'poll_option_id': optId,
        'voter_id': voterId,
      });

      return {
        'success': true,
        'message': 'Vote Recorded: Your response has been submitted.',
      };
    } catch (e) {
      final msg = e.toString();
      debugPrint('Supabase castProjectVote error: $e');
      if (msg.contains('23505') || msg.toLowerCase().contains('duplicate') || msg.toLowerCase().contains('unique')) {
        return {
          'success': false,
          'message': 'You have already voted for this event. You cannot change your vote.',
        };
      }
      return {'success': false, 'message': 'Error recording vote: $e'};
    }
  }

  // ─── QR Attendance (Scanner for Staff & Admin Only) ─────────────────────────

  Future<Map<String, dynamic>> validateAndMarkAttendanceByQr({
    required String qrOrRoll,
    required String eventId,
    required String session,
    required String scannedBy,
  }) async {
    final c = client;
    if (c == null) {
      return {'success': false, 'message': 'Supabase client is not connected'};
    }

    final query = qrOrRoll.trim();
    if (query.isEmpty) {
      return {'success': false, 'message': 'Invalid QR token or roll number'};
    }

    try {
      final studentRes = await c
          .from('profiles')
          .select()
          .or('id.eq.$query,roll_number.ilike.$query,email.ilike.$query')
          .maybeSingle();

      if (studentRes == null) {
        return {
          'success': false,
          'message': 'No student found matching QR token or Roll No: $query',
        };
      }

      final studentId = studentRes['id']?.toString() ?? '';
      final studentRoll = studentRes['roll_number']?.toString() ?? query;
      final studentName = studentRes['full_name']?.toString() ?? 'Student';

      final isScannedByUuid = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(scannedBy);

      await c.from('event_attendance').insert({
        'event_id': eventId,
        'student_id': studentId,
        'scanned_by': isScannedByUuid ? scannedBy : null,
        'status': 'present',
        'session': session.isNotEmpty ? session : 'Main',
      });

      return {
        'success': true,
        'studentName': studentName,
        'studentRoll': studentRoll,
        'department': studentRes['department'] ?? 'Information Technology',
        'year': studentRes['year'] ?? '3rd Year',
        'message': 'Attendance marked successfully: $studentName ($studentRoll)',
      };
    } catch (e) {
      debugPrint('validateAndMarkAttendanceByQr error: $e');
      return {'success': false, 'message': 'Error recording attendance: $e'};
    }
  }

  Future<List<AttendanceLog>> fetchAttendanceLogs(String? studentRoll) async {
    final c = client;
    if (c == null) return [];

    try {
      var query = c
          .from('event_attendance')
          .select('id, event_id, student_id, scanned_by, status, session, scanned_at, profiles!inner(full_name, roll_number), events(title, venue)');

      if (studentRoll != null && studentRoll.isNotEmpty) {
        query = query.ilike('profiles.roll_number', studentRoll.trim());
      }

      final res = await query.order('scanned_at', ascending: false).limit(40);

      return res.map((r) {
        final dateStr = (r['scanned_at'] ?? DateTime.now().toIso8601String()).toString();
        final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
        final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        final ev = r['events'] as Map<String, dynamic>?;
        return AttendanceLog(
          id: r['id']?.toString() ?? 'log',
          date: '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
          time: timeStr,
          subject: ev?['title']?.toString() ?? r['event_id']?.toString() ?? 'Department Session',
          room: ev?['venue']?.toString() ?? 'Turnstile Gate #2',
          status: (r['status']?.toString() ?? 'present').toUpperCase() == 'PRESENT' ? 'Present' : 'Late',
        );
      }).toList();
    } catch (e) {
      debugPrint('SupabaseService.fetchAttendanceLogs error: $e');
      return [];
    }
  }

  // ─── Polls (Students Vote; Staff/Admin Manage) ─────────────────────────────

  Future<List<PollModel>> fetchPolls({String? userId}) async {
    final c = client;
    if (c == null) return [];

    try {
      final pollsRes = await c
          .from('polls')
          .select()
          .order('created_at', ascending: false);

      final List<PollModel> polls = [];
      for (final p in pollsRes) {
        final pollId = p['id'].toString();

        final optsRes = await c
            .from('poll_options')
            .select()
            .eq('poll_id', pollId)
            .order('display_order', ascending: true);

        int? votedIndex;
        if (userId != null) {
          final voteRes = await c
              .from('poll_votes')
              .select('poll_option_id')
              .eq('poll_id', pollId)
              .eq('voter_id', userId)
              .maybeSingle();

          if (voteRes != null) {
            final optId = voteRes['poll_option_id'].toString();
            for (int i = 0; i < optsRes.length; i++) {
              if (optsRes[i]['id'].toString() == optId) {
                votedIndex = i;
                break;
              }
            }
          }
        }

        // Student privacy: do not expose vote counts to students
        final options = optsRes.map((o) => PollOption(
          id: o['id'].toString(),
          text: o['title'] ?? '',
          votes: 0,
          imageUrl: null,
          description: o['description']?.toString(),
        )).toList();

        final isActive = p['is_active'] == true;

        polls.add(PollModel(
          id: pollId,
          question: p['title'] ?? '',
          description: p['description'] ?? '',
          category: 'Department',
          options: options,
          userVotedIndex: votedIndex,
          expiresText: isActive ? 'Active Poll' : 'Closed',
          status: isActive ? 'OPEN' : 'CLOSED',
        ));
      }
      return polls;
    } catch (e) {
      debugPrint('Supabase fetchPolls error: $e');
      return [];
    }
  }

  Future<bool> castVote({
    required String pollId,
    required String optionId,
    required String userId,
  }) async {
    final c = client;
    if (c == null) return false;

    try {
      await c.from('poll_votes').insert({
        'poll_id': pollId,
        'poll_option_id': optionId,
        'voter_id': userId,
      });
      return true;
    } catch (e) {
      debugPrint('Supabase castVote error: $e');
      return false;
    }
  }

  Future<bool> createPoll({
    required String question,
    required String description,
    required String category,
    required List<String> options,
  }) async {
    final c = client;
    if (c == null) return false;

    try {
      final pollRes = await c.from('polls').insert({
        'title': question,
        'description': description,
        'is_active': true,
      }).select('id').single();

      final pollId = pollRes['id'];

      final List<Map<String, dynamic>> optRows = [];
      for (int i = 0; i < options.length; i++) {
        optRows.add({
          'poll_id': pollId,
          'title': options[i],
          'display_order': i + 1,
        });
      }
      await c.from('poll_options').insert(optRows);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.createPoll error: $e');
      return false;
    }
  }

  Future<bool> togglePollStatus(String pollId, String newStatus) async {
    final c = client;
    if (c == null) return false;

    try {
      final isActive = newStatus.toUpperCase() == 'OPEN';
      await c.from('polls').update({'is_active': isActive}).eq('id', pollId);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.togglePollStatus error: $e');
      return false;
    }
  }

  // ─── Notifications & Broadcasts ──────────────────────────────────────────

  Future<List<AppNotification>> fetchNotifications({String? userId}) async {
    return [];
  }

  Future<bool> broadcastNotification({
    required String title,
    required String message,
    String category = 'Urgent',
    String targetAudience = 'ALL',
  }) async {
    return true;
  }

  // ─── Students & Staff Directories (Staff & Admin) ──────────────────────────

  Future<List<UserModel>> fetchStudentsList({String? yearFilter, String? search}) async {
    final c = client;
    if (c == null) return [];

    try {
      var query = c.from('profiles').select().eq('role', 'student');
      if (yearFilter != null && yearFilter != 'All') {
        query = query.ilike('year', '%$yearFilter%');
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim();
        query = query.or('roll_number.ilike.%$q%,full_name.ilike.%$q%,email.ilike.%$q%');
      }

      final res = await query.order('roll_number', ascending: true).limit(500);

      return res.map((s) => _mapProfileRowToUser(s)).toList();
    } catch (e) {
      debugPrint('SupabaseService.fetchStudentsList error: $e');
      return [];
    }
  }

  Future<List<UserModel>> fetchStaffList() async {
    final c = client;
    if (c == null) return [];

    try {
      final res = await c.from('profiles').select().eq('role', 'staff').order('full_name', ascending: true);
      return res.map((st) => _mapProfileRowToUser(st)).toList();
    } catch (e) {
      debugPrint('SupabaseService.fetchStaffList error: $e');
      return [];
    }
  }

  Future<bool> toggleStudentStatus(String rollNo, String newStatus) async {
    final c = client;
    if (c == null) return false;

    try {
      final isActive = newStatus.toUpperCase() == 'ACTIVE';
      await c.from('profiles').update({'is_active': isActive}).eq('roll_number', rollNo);
      return true;
    } catch (e) {
      debugPrint('toggleStudentStatus error: $e');
      return false;
    }
  }

  Future<bool> updateAccountPassword(String newPassword) async {
    final c = client;
    if (c == null) return false;

    try {
      await c.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } catch (e) {
      debugPrint('updateAccountPassword error: $e');
      return false;
    }
  }

  // ─── Live Competition Leaderboard ──────────────────────────────────────────

  List<LiveLeaderboardEntry> getLiveLeaderboard() {
    return [
      LiveLeaderboardEntry(
        rank: 1,
        title: "Vibe Coding Hackathon",
        participant: "Team NeuralForge",
        rollNumber: "22IT049 & 22IT052",
        scoreOrTime: "98.5 pts",
        status: "Leading",
      ),
      LiveLeaderboardEntry(
        rank: 2,
        title: "Vibe Coding Hackathon",
        participant: "ByteShift Duo",
        rollNumber: "23K61A1205",
        scoreOrTime: "94.0 pts",
        status: "Runner Up",
      ),
      LiveLeaderboardEntry(
        rank: 3,
        title: "Vibe Coding Hackathon",
        participant: "AlgoRhythm Batch",
        rollNumber: "22IT088",
        scoreOrTime: "89.2 pts",
        status: "Evaluated",
      ),
      LiveLeaderboardEntry(
        rank: 1,
        title: "National Tech Quiz",
        participant: "K. Sarvagna",
        rollNumber: "22IT012",
        scoreOrTime: "48/50",
        status: "Top Scorer",
      ),
    ];
  }
}
