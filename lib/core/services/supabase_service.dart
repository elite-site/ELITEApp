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

    final u = username.trim().toLowerCase();
    final p = password.trim();

    try {
      String? matchedUserId;

      // 1. Check students table (roll_no = username, password_hash = password)
      final studentRes = await c
          .from('students')
          .select('user_id')
          .eq('roll_no', u.toUpperCase())
          .eq('password_hash', p.toLowerCase())
          .maybeSingle();

      if (studentRes != null) {
        matchedUserId = studentRes['user_id']?.toString();
      }

      // 2. Check staff table (username/employee_id + password_hash)
      if (matchedUserId == null) {
        final staffRes = await c
            .from('staff')
            .select('user_id')
            .or('username.ilike.$u,employee_id.ilike.$u')
            .eq('password_hash', p)
            .maybeSingle();
        if (staffRes != null) {
          matchedUserId = staffRes['user_id']?.toString();
        }
      }

      // 3. Check users table for admin (username + password_hash)
      if (matchedUserId == null) {
        final adminRes = await c
            .from('users')
            .select('id')
            .or('username.ilike.$u,email.ilike.$u')
            .eq('password_hash', p)
            .inFilter('role', ['SUPER_ADMIN', 'ADMIN'])
            .maybeSingle();
        if (adminRes != null) {
          matchedUserId = adminRes['id']?.toString();
        }
      }

      if (matchedUserId == null) {
        return null;
      }

      // 4. Fetch authoritative server-side profile and role from `profiles` table
      return await fetchUserProfileById(matchedUserId);
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

    String prefix = q;
    if (q.contains('@')) {
      prefix = q.split('@').first.trim();
    }

    try {
      // Authoritative lookup on profiles table
      final res = await c
          .from('profiles')
          .select()
          .or('id.eq.$q,email.ilike.$q,student_id.ilike.$prefix,student_id.ilike.$q')
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

    return UserModel(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? 'User',
      email: row['email']?.toString() ?? '',
      rollNumber: row['student_id']?.toString() ?? '',
      role: userRole,
      department: row['department']?.toString() ?? 'Information Technology',
      academicDetails: row['academic_details']?.toString() ??
          (userRole == UserRole.student ? 'B.Tech IT' : 'Department Faculty'),
      yearLevel: row['year']?.toString() ??
          (userRole == UserRole.student ? '3rd Year' : 'Faculty'),
      section: row['section']?.toString() ?? 'A',
      phoneNumber: row['phone_number']?.toString() ?? '',
      status: row['status']?.toString() ?? 'ACTIVE',
      labPassId: row['lab_pass_id']?.toString() ?? 'ELITE_QR_PASS',
      labPassRoom: row['lab_pass_room']?.toString() ?? 'IT Lab & Turnstile Gate #2',
      labPassExpiry: row['lab_pass_expiry']?.toString() ?? 'AY 2026-2027',
      cgpa: (row['cgpa'] as num?)?.toDouble() ??
          (userRole == UserRole.student ? 8.94 : 0.0),
      attendancePercent: (row['attendance_percent'] as num?)?.toInt() ?? 90,
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

        final maxCap = (row['max_capacity'] as num?)?.toInt() ?? 100;
        final regCount = (row['registered_count'] as num?)?.toInt() ?? 0;
        final title = (row['title'] ?? '').toString();
        final cat = (row['event_type'] ?? 'Technical').toString();
        final partType = (row['participation_type'] ?? '').toString();
        final isTeam = row['is_team'] == true ||
            partType.toLowerCase().contains('team') ||
            cat.toLowerCase().contains('hackathon') ||
            title.toLowerCase().contains('hackathon') ||
            title.toLowerCase().contains('vibe') ||
            title.toLowerCase().contains('pitch');

        final isProjEnabled = row['is_project_submission_enabled'] == true || isTeam;
        final projDeadline = row['project_submission_deadline'] != null
            ? DateTime.tryParse(row['project_submission_deadline'].toString())
            : DateTime(2026, 9, 15, 18, 0);

        final isVoteEnabled = row['is_voting_enabled'] == true;
        final vStart = row['voting_start'] != null ? DateTime.tryParse(row['voting_start'].toString()) : null;
        final vEnd = row['voting_end'] != null ? DateTime.tryParse(row['voting_end'].toString()) : null;
        List<String> vRoles = ['STUDENT', 'STAFF'];
        if (row['voting_eligible_roles'] is List) {
          vRoles = (row['voting_eligible_roles'] as List).map((e) => e.toString()).toList();
        }

        list.add(EventModel(
          id: row['id'].toString(),
          title: row['title'] ?? 'Department Event',
          description: row['description'] ?? '',
          category: cat,
          dateMonth: month,
          dateDay: day,
          time: '${row['start_time'] ?? '10:00 AM'} - ${row['end_time'] ?? '04:00 PM'}',
          venue: row['venue'] ?? 'Campus Auditorium',
          speaker: row['faculty_coordinators'] ?? 'Department Faculty',
          seatsLeft: (maxCap - regCount).clamp(0, maxCap),
          totalSeats: maxCap,
          isRegistered: false,
          rules: row['rules']?.toString() ?? '',
          status: (row['status'] ?? 'OPEN').toString().toUpperCase(),
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
    required int maxCapacity,
    required String facultyCoordinators,
    required String rules,
  }) async {
    final c = client;
    if (c == null) return false;

    try {
      final id = 'ev_${DateTime.now().millisecondsSinceEpoch}';
      await c.from('events').insert({
        'id': id,
        'title': title,
        'description': description,
        'event_type': category,
        'venue': venue,
        'event_date': eventDate,
        'start_time': startTime,
        'end_time': endTime,
        'max_capacity': maxCapacity,
        'registered_count': 0,
        'faculty_coordinators': facultyCoordinators,
        'rules': rules,
        'status': 'OPEN',
        'created_at': DateTime.now().toIso8601String(),
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
          .select()
          .eq('event_id', eventId)
          .order('registered_at', ascending: false);

      return res.map((r) {
        List<TeamMemberInfo> memberList = [];
        if (r['members'] != null && r['members'] is List) {
          memberList = (r['members'] as List)
              .map((m) => TeamMemberInfo.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList();
        }
        return EventRegistrationModel(
          id: r['id']?.toString() ?? '',
          eventId: r['event_id']?.toString() ?? eventId,
          isTeam: r['is_team'] == true,
          teamName: r['team_name']?.toString(),
          studentId: r['student_id']?.toString() ?? '',
          studentRoll: r['student_roll']?.toString() ?? '',
          studentName: r['student_name']?.toString() ?? 'Student',
          studentEmail: r['student_email']?.toString() ?? '',
          studentYear: r['student_year']?.toString() ?? '3rd Year',
          members: memberList,
          status: r['status']?.toString() ?? 'CONFIRMED',
          registeredAt: r['registered_at']?.toString() ?? '',
        );
      }).toList();
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
      final regId = '${eventId}_${user.id}';
      final member = TeamMemberInfo(
        studentId: user.id,
        studentRoll: user.rollNumber,
        studentName: user.name,
        studentEmail: user.email,
        studentDept: user.department,
        studentYear: user.yearLevel,
        isLeader: true,
      );

      await c.from('event_registrations').upsert({
        'id': regId,
        'event_id': eventId,
        'is_team': false,
        'student_id': user.id,
        'student_roll': user.rollNumber,
        'student_name': user.name,
        'student_email': user.email,
        'student_year': user.yearLevel,
        'members': [member.toJson()],
        'status': 'CONFIRMED',
        'registered_at': DateTime.now().toIso8601String(),
      });

      // Update registered count in events table
      try {
        final ev = await c.from('events').select('registered_count').eq('id', eventId).single();
        final cur = (ev['registered_count'] as num?)?.toInt() ?? 0;
        await c.from('events').update({'registered_count': cur + 1}).eq('id', eventId);
      } catch (_) {}

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
      final regId = 'team_${eventId}_${DateTime.now().millisecondsSinceEpoch}';
      final membersJson = members.map((m) => m.toJson()).toList();

      await c.from('event_registrations').upsert({
        'id': regId,
        'event_id': eventId,
        'is_team': true,
        'team_name': teamName,
        'student_id': leader.id,
        'student_roll': leader.rollNumber,
        'student_name': leader.name,
        'student_email': leader.email,
        'student_year': leader.yearLevel,
        'members': membersJson,
        'status': 'CONFIRMED',
        'registered_at': DateTime.now().toIso8601String(),
      });

      // Update registered count in events table
      try {
        final ev = await c.from('events').select('registered_count').eq('id', eventId).single();
        final cur = (ev['registered_count'] as num?)?.toInt() ?? 0;
        await c.from('events').update({'registered_count': cur + members.length}).eq('id', eventId);
      } catch (_) {}

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
      final regId = '${eventId}_$userId';
      await c.from('event_registrations').delete().eq('id', regId);

      // Decrement count
      try {
        final ev = await c.from('events').select('registered_count').eq('id', eventId).single();
        final cur = (ev['registered_count'] as num?)?.toInt() ?? 1;
        await c.from('events').update({'registered_count': (cur - 1).clamp(0, 9999)}).eq('id', eventId);
      } catch (_) {}

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
          .select('event_id, student_id, student_roll, members');

      final Set<String> registeredEventIds = {};
      final uId = userId.trim().toLowerCase();
      final uRoll = (rollNumber ?? '').trim().toUpperCase();

      for (final r in res) {
        final evId = r['event_id']?.toString();
        if (evId == null) continue;

        // 1. Direct leader / individual registration
        final sId = r['student_id']?.toString().toLowerCase();
        final sRoll = r['student_roll']?.toString().toUpperCase();
        if (sId == uId || (uRoll.isNotEmpty && sRoll == uRoll)) {
          registeredEventIds.add(evId);
          continue;
        }

        // 2. Team membership check in members JSON
        final membersData = r['members'];
        if (membersData is List) {
          for (final m in membersData) {
            if (m is Map) {
              final mId = m['student_id']?.toString().toLowerCase() ?? m['studentId']?.toString().toLowerCase();
              final mRoll = m['student_roll']?.toString().toUpperCase() ?? m['studentRoll']?.toString().toUpperCase();
              if (mId == uId || (uRoll.isNotEmpty && mRoll == uRoll)) {
                registeredEventIds.add(evId);
                break;
              }
            }
          }
        }
      }

      return registeredEventIds.toList();
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
      final res = await c
          .from('event_registrations')
          .select()
          .eq('event_id', eventId);

      final uId = userId.trim().toLowerCase();
      final uRoll = (rollNumber ?? '').trim().toUpperCase();

      for (final r in res) {
        final sId = r['student_id']?.toString().toLowerCase();
        final sRoll = r['student_roll']?.toString().toUpperCase();

        final isLeader = (sId == uId || (uRoll.isNotEmpty && sRoll == uRoll));

        bool isMember = false;
        final membersData = r['members'];
        if (membersData is List) {
          for (final m in membersData) {
            if (m is Map) {
              final mId = m['student_id']?.toString().toLowerCase() ?? m['studentId']?.toString().toLowerCase();
              final mRoll = m['student_roll']?.toString().toUpperCase() ?? m['studentRoll']?.toString().toUpperCase();
              if (mId == uId || (uRoll.isNotEmpty && mRoll == uRoll)) {
                isMember = true;
                break;
              }
            }
          }
        }

        if (isLeader || isMember) {
          return {
            'registrationId': r['id']?.toString() ?? '',
            'teamName': r['team_name']?.toString() ?? 'Team',
            'isLeader': isLeader,
            'role': isLeader ? 'Team Leader' : 'Team Member',
            'leaderName': r['student_name']?.toString() ?? 'Leader',
            'leaderRoll': r['student_roll']?.toString() ?? '',
            'membersCount': (membersData is List) ? membersData.length : 1,
            'isTeam': r['is_team'] == true,
          };
        }
      }
      return null;
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
      final res = await c
          .from('project_submissions')
          .select()
          .eq('event_id', eventId)
          .eq('registration_id', registrationId)
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
          .eq('status', 'PUBLISHED')
          .order('created_at', ascending: false);

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

      await c.storage.from('project_assets').uploadBinary(
        path,
        imageBytes,
        fileOptions: FileOptions(
          contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
          upsert: true,
        ),
      );

      final publicUrl = c.storage.from('project_assets').getPublicUrl(path);
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
      await c.from('project_submissions').upsert({
        'id': project.id,
        'event_id': project.eventId,
        'registration_id': project.registrationId,
        'team_name': project.teamName,
        'leader_id': project.leaderId,
        'leader_name': project.leaderName,
        'project_name': project.projectName,
        'short_description': project.shortDescription,
        'detailed_description': project.detailedDescription,
        'technologies': project.technologies,
        'repo_url': project.repoUrl,
        'demo_url': project.demoUrl,
        'documentation_url': project.documentationUrl,
        'presentation_url': project.presentationUrl,
        'image_url': project.imageUrl,
        'status': project.status,
      });

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
      final res = await c
          .from('project_votes')
          .select('id')
          .eq('event_id', eventId)
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
      final voteId = 'vote_${eventId}_$voterId';
      await c.from('project_votes').insert({
        'id': voteId,
        'event_id': eventId,
        'project_id': projectId,
        'voter_id': voterId,
        'voter_role': voterRole.toUpperCase(),
        'voted_at': DateTime.now().toIso8601String(),
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
      if (msg.toLowerCase().contains('ended')) {
        return {'success': false, 'message': 'Voting has ended.'};
      }
      if (msg.toLowerCase().contains('not started')) {
        return {'success': false, 'message': 'Voting has not started yet.'};
      }
      if (msg.toLowerCase().contains('not eligible')) {
        return {'success': false, 'message': 'Your role is not eligible to vote in this event.'};
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
      // 1. Search student in database
      final studentRes = await c
          .from('students')
          .select()
          .or('qr_token.eq.$query,roll_no.ilike.$query')
          .maybeSingle();

      if (studentRes == null) {
        return {
          'success': false,
          'message': 'No student found matching QR token or Roll No: $query',
        };
      }

      final studentId = studentRes['user_id']?.toString() ?? 'u_${studentRes['roll_no']}';
      final studentRoll = studentRes['roll_no']?.toString() ?? query;
      final studentName = studentRes['name']?.toString() ?? 'Student';
      final studentEmail = studentRes['email']?.toString() ?? '';

      // 2. Insert into event_attendance
      final attId = 'ATT-${DateTime.now().millisecondsSinceEpoch}';
      await c.from('event_attendance').insert({
        'id': attId,
        'event_id': eventId,
        'student_id': studentId,
        'student_roll': studentRoll,
        'student_name': studentName,
        'student_email': studentEmail,
        'scanned_by': scannedBy,
        'status': 'PRESENT',
        'session': session,
        'scanned_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'studentName': studentName,
        'studentRoll': studentRoll,
        'department': studentRes['department'] ?? 'Information Technology',
        'year': studentRes['year_level'] ?? '3rd Year',
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
      var query = c.from('event_attendance').select();
      if (studentRoll != null && studentRoll.isNotEmpty) {
        query = query.ilike('student_roll', studentRoll.trim());
      }

      final res = await query.order('scanned_at', ascending: false).limit(40);

      return res.map((r) {
        final dateStr = (r['scanned_at'] ?? DateTime.now().toIso8601String()).toString();
        final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
        final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        return AttendanceLog(
          id: r['id']?.toString() ?? 'log',
          date: '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
          time: timeStr,
          subject: r['event_id']?.toString() ?? 'Department Session',
          room: r['scanned_by']?.toString() ?? 'Turnstile Gate #2',
          status: (r['status']?.toString() ?? 'PRESENT').toUpperCase() == 'PRESENT' ? 'Present' : 'Late',
        );
      }).toList();
    } catch (e) {
      debugPrint('SupabaseService.fetchAttendanceLogs error: $e');
      return [];
    }
  }

  // ─── Polls (Students Vote; Staff/Admin Manage; Staff Does NOT Vote) ─────────

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
            .eq('poll_id', pollId);

        int? votedIndex;
        if (userId != null) {
          final voteRes = await c
              .from('poll_votes')
              .select('option_id')
              .eq('poll_id', pollId)
              .eq('student_id', userId)
              .maybeSingle();

          if (voteRes != null) {
            final optId = voteRes['option_id'].toString();
            for (int i = 0; i < optsRes.length; i++) {
              if (optsRes[i]['id'].toString() == optId) {
                votedIndex = i;
                break;
              }
            }
          }
        }

        final options = optsRes.map((o) => PollOption(
          id: o['id'].toString(),
          text: o['text'] ?? '',
          votes: (o['vote_count'] as num?)?.toInt() ?? 0,
          imageUrl: o['image_url']?.toString(),
          description: o['description']?.toString(),
        )).toList();

        polls.add(PollModel(
          id: pollId,
          question: p['question'] ?? '',
          description: p['description'] ?? '',
          category: p['category'] ?? 'Department',
          options: options,
          userVotedIndex: votedIndex,
          expiresText: p['status'] == 'OPEN' ? 'Active Poll' : 'Closed',
          status: p['status'] ?? 'OPEN',
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
      final voteId = '${pollId}_$userId';
      await c.from('poll_votes').upsert({
        'id': voteId,
        'poll_id': pollId,
        'option_id': optionId,
        'student_id': userId,
        'voted_at': DateTime.now().toIso8601String(),
      });

      // Increment vote count on option
      try {
        final opt = await c.from('poll_options').select('vote_count').eq('id', optionId).single();
        final current = (opt['vote_count'] as num?)?.toInt() ?? 0;
        await c.from('poll_options').update({'vote_count': current + 1}).eq('id', optionId);
      } catch (_) {}

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
      final pollId = 'poll_${DateTime.now().millisecondsSinceEpoch}';
      await c.from('polls').insert({
        'id': pollId,
        'question': question,
        'description': description,
        'category': category,
        'target_years': 'All',
        'status': 'OPEN',
        'created_at': DateTime.now().toIso8601String(),
      });

      final List<Map<String, dynamic>> optRows = [];
      for (int i = 0; i < options.length; i++) {
        optRows.add({
          'id': 'opt_${pollId}_$i',
          'poll_id': pollId,
          'text': options[i],
          'vote_count': 0,
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
      await c.from('polls').update({'status': newStatus}).eq('id', pollId);
      return true;
    } catch (e) {
      debugPrint('SupabaseService.togglePollStatus error: $e');
      return false;
    }
  }

  // ─── Notifications & Broadcasts ──────────────────────────────────────────

  Future<List<AppNotification>> fetchNotifications({String? userId}) async {
    final c = client;
    if (c == null) return [];

    try {
      final notifsRes = await c
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(40);

      Set<String> readIds = {};
      if (userId != null) {
        final readsRes = await c
            .from('notification_reads')
            .select('notification_id')
            .eq('user_id', userId);
        readIds = readsRes.map((r) => r['notification_id'].toString()).toSet();
      }

      final List<AppNotification> list = [];
      for (final n in notifsRes) {
        final nId = n['id'].toString();
        list.add(AppNotification(
          id: nId,
          title: n['title'] ?? 'Notice',
          message: n['message'] ?? '',
          timeAgo: 'Recent',
          category: n['category'] ?? 'System',
          isRead: readIds.contains(nId),
        ));
      }
      return list;
    } catch (e) {
      debugPrint('Supabase fetchNotifications error: $e');
      return [];
    }
  }

  Future<bool> broadcastNotification({
    required String title,
    required String message,
    String category = 'Urgent',
    String targetAudience = 'ALL',
  }) async {
    final c = client;
    if (c == null) return false;

    try {
      await c.from('notifications').insert({
        'id': 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
        'title': title,
        'message': message,
        'category': category,
        'target_audience': targetAudience,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Supabase broadcastNotification error: $e');
      return false;
    }
  }

  // ─── Students & Staff Directories (Staff & Admin) ──────────────────────────

  Future<List<UserModel>> fetchStudentsList({String? yearFilter, String? search}) async {
    final c = client;
    if (c == null) return [];

    try {
      var query = c.from('students').select();
      if (yearFilter != null && yearFilter != 'All') {
        query = query.ilike('year_level', '%$yearFilter%');
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim();
        query = query.or('roll_no.ilike.%$q%,name.ilike.%$q%');
      }

      final res = await query.order('roll_no', ascending: true).limit(500);

      return res.map((s) => UserModel(
        id: s['user_id']?.toString() ?? '',
        name: s['name']?.toString() ?? 'Student',
        email: s['email']?.toString() ?? '',
        rollNumber: s['roll_no']?.toString() ?? '',
        role: UserRole.student,
        department: s['department']?.toString() ?? 'Information Technology',
        academicDetails: 'B.Tech IT • ${s['year_level'] ?? '3rd Year'}',
        yearLevel: s['year_level']?.toString() ?? '3rd Year',
        section: s['section']?.toString() ?? 'B',
        status: s['status']?.toString() ?? 'ACTIVE',
        labPassId: s['qr_token']?.toString() ?? 'PASS',
      )).toList();
    } catch (e) {
      debugPrint('SupabaseService.fetchStudentsList error: $e');
      return [];
    }
  }

  Future<List<UserModel>> fetchStaffList() async {
    final c = client;
    if (c == null) return [];

    try {
      final res = await c.from('staff').select().order('employee_id', ascending: true);
      return res.map((st) => UserModel(
        id: st['user_id']?.toString() ?? '',
        name: st['name']?.toString() ?? 'Faculty Member',
        email: st['email']?.toString() ?? '',
        rollNumber: st['employee_id']?.toString() ?? '',
        role: UserRole.staff,
        department: st['department']?.toString() ?? 'Information Technology',
        academicDetails: st['designation']?.toString() ?? 'Faculty Coordinator',
        section: st['cabin']?.toString() ?? 'IT Staff Room',
        phoneNumber: st['phone']?.toString() ?? '',
      )).toList();
    } catch (e) {
      debugPrint('SupabaseService.fetchStaffList error: $e');
      return [];
    }
  }

  Future<bool> toggleStudentStatus(String rollNo, String newStatus) async {
    final c = client;
    if (c == null) return false;

    try {
      await c.from('students').update({'status': newStatus}).eq('roll_no', rollNo);
      return true;
    } catch (e) {
      debugPrint('toggleStudentStatus error: $e');
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
