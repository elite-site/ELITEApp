import 'dart:async';
import 'dart:typed_data';
export '../data/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/app_models.dart';
import '../data/repositories/mock_repository.dart';
import '../core/services/supabase_service.dart';

class AppState extends ChangeNotifier {
  final SupabaseService _supabaseService;
  Timer? _syncTimer;

  UserModel? _currentUser;
  List<EventModel> _events = MockRepository.getInitialEvents();
  final List<SubjectAttendance> _subjectAttendance = MockRepository.getSubjectAttendance();
  final List<AttendanceLog> _attendanceLogs = MockRepository.getAttendanceLogs();
  List<PollModel> _polls = MockRepository.getInitialPolls();
  List<AppNotification> _notifications = MockRepository.getInitialNotifications();
  List<LiveLeaderboardEntry> _leaderboard = [];

  // Registrations (loaded from Supabase on sync)
  final List<EventRegistrationModel> _registrations = [];

  // Student roster — loaded from Supabase on sync
  List<UserModel> _studentsRoster = [];
  List<UserModel> _staffRoster = [];

  String _selectedEventCategory = "All";
  bool _isLoadingFromSupabase = false;
  bool _isRestoringSession = true;

  AppState([SupabaseService? supabaseService])
      : _supabaseService = supabaseService ?? SupabaseService() {
    _leaderboard = _supabaseService.getLiveLeaderboard();
    _restoreSession();

    // 1. Parallel Realtime Sync with Supabase (instant WebSocket updates)
    _supabaseService.subscribeToRealtimeChanges(() {
      if (isLoggedIn) {
        debugPrint('⚡ Realtime parallel sync triggered in Flutter App');
        syncFromSupabase();
      }
    });

    // 2. High-frequency parallel sync interval (every 5 seconds)
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isLoggedIn) {
        syncFromSupabase();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    _isRestoringSession = true;
    _isLoadingFromSupabase = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isActive = prefs.getBool('elite_session_active') ?? false;
      final String? savedUserId = prefs.getString('elite_session_user_id');
      final String? savedEmail = prefs.getString('elite_session_email');

      if (isActive && ((savedUserId != null && savedUserId.isNotEmpty) || (savedEmail != null && savedEmail.isNotEmpty))) {
        debugPrint('AppState: Restoring persisted user session for ID=$savedUserId, email=$savedEmail');
        UserModel? profile;
        if (savedUserId != null && savedUserId.isNotEmpty) {
          profile = await _supabaseService.fetchUserProfileById(savedUserId);
        }
        if (profile == null && savedEmail != null && savedEmail.isNotEmpty) {
          profile = await _supabaseService.fetchUserProfile(savedEmail);
        }

        if (profile != null && profile.id.isNotEmpty) {
          _currentUser = profile;
          await syncFromSupabase();
          debugPrint('AppState: Successfully restored session for ${profile.name} (${profile.role})');
        } else {
          debugPrint('AppState: Persisted user profile not found on Supabase. Clearing stale session.');
          await prefs.remove('elite_session_active');
          await prefs.remove('elite_session_user_id');
          await prefs.remove('elite_session_email');
          await prefs.remove('elite_session_roll');
          await prefs.remove('elite_session_role');
        }
      }
    } catch (e) {
      debugPrint('AppState._restoreSession error: $e');
    } finally {
      _isLoadingFromSupabase = false;
      _isRestoringSession = false;
      notifyListeners();
    }
  }

  UserModel get currentUser => _currentUser ?? UserModel.empty();
  bool get isRestoringSession => _isRestoringSession;
  bool get isLoggedIn => _currentUser != null && _currentUser!.id.isNotEmpty;
  bool get isStudent => _currentUser?.isStudent == true;
  bool get isStaff => _currentUser?.isStaff == true;
  bool get isAdmin => _currentUser?.isAdmin == true;

  List<EventModel> get events => _events;
  List<EventRegistrationModel> get registrations => _registrations;
  List<SubjectAttendance> get subjectAttendance => _subjectAttendance;
  List<AttendanceLog> get attendanceLogs => _attendanceLogs;
  List<PollModel> get polls => _polls;
  List<AppNotification> get notifications => _notifications;
  List<LiveLeaderboardEntry> get leaderboard => _leaderboard;
  List<UserModel> get studentsRoster => _studentsRoster;
  List<UserModel> get staffRoster => _staffRoster;

  String get selectedEventCategory => _selectedEventCategory;
  bool get isLoadingFromSupabase => _isLoadingFromSupabase;
  bool get isSupabaseConnected => _supabaseService.isInitialized;

  int get unreadNotificationCount => _notifications.where((n) => !n.isRead).length;

  List<EventModel> get filteredEvents {
    if (_selectedEventCategory == "All") return _events;
    return _events.where((e) => e.category.toLowerCase() == _selectedEventCategory.toLowerCase()).toList();
  }

  List<EventModel> get registeredEvents {
    return _events.where((e) => isStudentRegisteredForEvent(e.id)).toList();
  }

  /// Check if the currently logged-in student (or specified student) is registered for an event
  EventRegistrationModel? getRegistrationForEvent(String eventId, [String? studentRollOrEmail]) {
    final target = (studentRollOrEmail ?? currentUser.rollNumber).trim().toLowerCase();
    for (final reg in _registrations) {
      if (reg.eventId == eventId && reg.containsStudent(target)) {
        return reg;
      }
    }
    return null;
  }

  bool isStudentRegisteredForEvent(String eventId, [String? studentRollOrEmail]) {
    return getRegistrationForEvent(eventId, studentRollOrEmail) != null;
  }

  /// Check if a student is already registered for this event in any team
  bool isStudentRegisteredInAnyTeam(String eventId, String studentRollOrEmail) {
    final target = studentRollOrEmail.trim().toLowerCase();
    return _registrations.any((r) => r.eventId == eventId && r.containsStudent(target));
  }

  // ─── Authentication ──────────────────────────────────────────────────────────

  /// Login with roll number (or admin username) + password.
  /// Students: roll_no + password_hash (same as roll_no lowercase, stored in students table).
  /// Staff: username/employee_id + password_hash (stored in staff table).
  /// Admin: username + password_hash (stored in users table with role SUPER_ADMIN).
  Future<Map<String, dynamic>> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    _isLoadingFromSupabase = true;
    notifyListeners();

    try {
      final profile = await _supabaseService.fetchUserByCredentials(
        username: username.trim(),
        password: password.trim(),
      );

      if (profile != null) {
        _currentUser = profile;

        // Persist session to device storage so app restart keeps user logged in
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('elite_session_active', true);
          await prefs.setString('elite_session_user_id', profile.id);
          await prefs.setString('elite_session_email', profile.email);
          await prefs.setString('elite_session_roll', profile.rollNumber);
          await prefs.setString('elite_session_role', profile.role.name);
          await prefs.setInt('elite_session_timestamp', DateTime.now().millisecondsSinceEpoch);
          debugPrint('AppState: Session securely persisted for ${profile.email} (${profile.role.name})');
        } catch (err) {
          debugPrint('AppState: Warning persisting session: $err');
        }

        await syncFromSupabase();
        _isLoadingFromSupabase = false;
        notifyListeners();
        return {'success': true};
      }

      _isLoadingFromSupabase = false;
      notifyListeners();
      return {'success': false, 'message': 'Invalid credentials. Please try again.'};
    } catch (e) {
      _isLoadingFromSupabase = false;
      notifyListeners();
      return {'success': false, 'message': 'Login failed: $e'};
    }
  }

  Future<void> logout() async {
    // Explicit logout only
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('elite_session_active');
      await prefs.remove('elite_session_user_id');
      await prefs.remove('elite_session_email');
      await prefs.remove('elite_session_roll');
      await prefs.remove('elite_session_role');
      await prefs.remove('elite_session_timestamp');
      debugPrint('AppState: Explicit logout - cleared session from device storage.');
    } catch (err) {
      debugPrint('AppState: Error clearing local session on logout: $err');
    }

    try {
      await SupabaseService.client?.auth.signOut();
    } catch (_) {}
    _currentUser = null;
    _events = [];
    _polls = [];
    _notifications = [];
    _registrations.clear();
    _attendanceLogs.clear();
    notifyListeners();
  }

  // ─── Supabase Data Synchronization ─────────────────────────────────────────

  Future<void> syncFromSupabase() async {
    if (!_supabaseService.isInitialized) return;
    final user = _currentUser;
    if (user == null || user.id.isEmpty) return;

    _isLoadingFromSupabase = true;
    notifyListeners();

    try {
      // 1. Fetch live user profile
      final liveUser = await _supabaseService.fetchUserProfile(user.email);
      if (liveUser != null) {
        _currentUser = liveUser;
      }

      // 2. Fetch live attendance logs
      final liveLogs = await _supabaseService.fetchAttendanceLogs(
        user.isStudent ? user.rollNumber : null,
      );
      if (liveLogs.isNotEmpty) {
        _attendanceLogs.clear();
        _attendanceLogs.addAll(liveLogs);
      }

      // 3. Fetch live events
      final supaEvents = await _supabaseService.fetchEvents();
      if (supaEvents.isNotEmpty) {
        final registeredIds = await _supabaseService.fetchUserRegisteredEventIds(
          currentUser.id,
          rollNumber: currentUser.rollNumber,
        );
        for (var ev in supaEvents) {
          if (registeredIds.contains(ev.id)) {
            ev.isRegistered = true;
          }
        }
        _events = supaEvents;
      }

      // 4. Fetch live polls
      final supaPolls = await _supabaseService.fetchPolls(userId: currentUser.id);
      if (supaPolls.isNotEmpty) {
        _polls = supaPolls;
      }

      // 5. Fetch live notifications
      final supaNotifs = await _supabaseService.fetchNotifications(userId: currentUser.id);
      if (supaNotifs.isNotEmpty) {
        _notifications = supaNotifs;
      }

      // 6. Fetch student and staff rosters
      final students = await _supabaseService.fetchStudentsList();
      if (students.isNotEmpty) _studentsRoster = students;

      if (currentUser.isStaff || currentUser.isAdmin) {
        final staff = await _supabaseService.fetchStaffList();
        if (staff.isNotEmpty) _staffRoster = staff;
      }

      _leaderboard = _supabaseService.getLiveLeaderboard();
    } catch (e) {
      debugPrint('AppState syncFromSupabase error: $e');
    } finally {
      _isLoadingFromSupabase = false;
      notifyListeners();
    }
  }

  void setEventCategory(String category) {
    _selectedEventCategory = category;
    notifyListeners();
  }

  // ─── Event Registration: Individual & Team Flows ───────────────────────────

  Future<Map<String, dynamic>> registerIndividualEvent({required String eventId}) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index == -1) {
      return {'success': false, 'message': 'Event not found.'};
    }

    if (isStudentRegisteredForEvent(eventId)) {
      return {'success': false, 'message': 'You are already registered for this event.'};
    }

    final target = _events[index];
    if (target.seatsLeft <= 0) {
      return {'success': false, 'message': 'Registration closed: No seats left.'};
    }

    final reg = EventRegistrationModel(
      id: 'reg_${eventId}_${currentUser.id}',
      eventId: eventId,
      isTeam: false,
      studentId: currentUser.id,
      studentRoll: currentUser.rollNumber,
      studentName: currentUser.name,
      studentEmail: currentUser.email,
      studentYear: currentUser.yearLevel,
      members: [
        TeamMemberInfo(
          studentId: currentUser.id,
          studentRoll: currentUser.rollNumber,
          studentName: currentUser.name,
          studentEmail: currentUser.email,
          studentDept: currentUser.department,
          studentYear: currentUser.yearLevel,
          isLeader: true,
        ),
      ],
      registeredAt: DateTime.now().toIso8601String(),
    );

    _registrations.insert(0, reg);
    target.isRegistered = true;
    target.seatsLeft = (target.seatsLeft - 1).clamp(0, target.totalSeats);
    notifyListeners();

    if (_supabaseService.isInitialized) {
      await _supabaseService.registerEvent(eventId: eventId, user: currentUser);
    }
    return {'success': true, 'message': 'Registration confirmed for ${target.title}!'};
  }

  Future<Map<String, dynamic>> registerTeamEvent({
    required String eventId,
    required String teamName,
    required List<TeamMemberInfo> members,
  }) async {
    final cleanTeamName = teamName.trim();
    if (cleanTeamName.isEmpty) {
      return {'success': false, 'message': 'Please provide a valid team name.'};
    }

    final index = _events.indexWhere((e) => e.id == eventId);
    if (index == -1) {
      return {'success': false, 'message': 'Event not found.'};
    }

    final target = _events[index];

    if (members.length < target.minTeamSize) {
      return {
        'success': false,
        'message': 'Team must have at least ${target.minTeamSize} members.',
      };
    }

    if (members.length > target.maxTeamSize) {
      return {
        'success': false,
        'message': 'Team exceeds maximum allowed size of ${target.maxTeamSize} members.',
      };
    }

    // Check duplicate registrations across team members
    for (final m in members) {
      if (isStudentRegisteredInAnyTeam(eventId, m.studentRoll) ||
          isStudentRegisteredInAnyTeam(eventId, m.studentEmail)) {
        return {
          'success': false,
          'message': '${m.studentName} (${m.studentRoll}) is already registered for this event.',
        };
      }
    }

    final reg = EventRegistrationModel(
      id: 'team_${eventId}_${DateTime.now().millisecondsSinceEpoch}',
      eventId: eventId,
      isTeam: true,
      teamName: cleanTeamName,
      studentId: currentUser.id,
      studentRoll: currentUser.rollNumber,
      studentName: currentUser.name,
      studentEmail: currentUser.email,
      studentYear: currentUser.yearLevel,
      members: members,
      registeredAt: DateTime.now().toIso8601String(),
    );

    _registrations.insert(0, reg);
    target.isRegistered = true;
    target.seatsLeft = (target.seatsLeft - members.length).clamp(0, target.totalSeats);
    notifyListeners();

    if (_supabaseService.isInitialized) {
      await _supabaseService.registerTeam(
        eventId: eventId,
        teamName: cleanTeamName,
        leader: currentUser,
        members: members,
      );
    }

    return {
      'success': true,
      'message': 'Team "$cleanTeamName" successfully registered with ${members.length} members!',
    };
  }

  Future<void> cancelEventRegistration(String eventId) async {
    _registrations.removeWhere((r) => r.eventId == eventId && r.containsStudent(currentUser.rollNumber));
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      _events[index].isRegistered = false;
      _events[index].seatsLeft = (_events[index].seatsLeft + 1).clamp(0, _events[index].totalSeats);
    }
    notifyListeners();
    if (_supabaseService.isInitialized) {
      await _supabaseService.cancelRegistration(eventId: eventId, userId: currentUser.id);
    }
  }

  // Backward compatibility alias
  Future<void> toggleEventRegistration(String eventId) async {
    if (isStudentRegisteredForEvent(eventId)) {
      await cancelEventRegistration(eventId);
    } else {
      await registerIndividualEvent(eventId: eventId);
    }
  }

  // ─── Project Submission & Voting ───────────────────────────────────────────

  Future<Map<String, dynamic>?> getTeamRegistration(String eventId) async {
    return _supabaseService.fetchTeamRegistrationForUser(
      eventId,
      currentUser.id,
      rollNumber: currentUser.rollNumber,
    );
  }

  Future<ProjectSubmissionModel?> getTeamProjectSubmission(String eventId, String registrationId) async {
    return _supabaseService.fetchTeamProjectSubmission(eventId, registrationId);
  }

  Future<Map<String, dynamic>> submitTeamProject(ProjectSubmissionModel project) async {
    return _supabaseService.submitProjectSubmission(project);
  }

  Future<String?> uploadProjectImage(Uint8List bytes, String ext, {String? fileName}) async {
    return _supabaseService.uploadProjectImage(bytes, ext, fileName: fileName);
  }

  Future<List<ProjectSubmissionModel>> getPublishedProjects(String eventId) async {
    return _supabaseService.fetchPublishedProjects(eventId);
  }

  Future<bool> hasVotedInEvent(String eventId) async {
    return _supabaseService.hasUserVotedForEvent(eventId, currentUser.id);
  }

  Future<Map<String, dynamic>> castProjectVote(String eventId, String projectId) async {
    final role = currentUser.isStaff ? 'STAFF' : 'STUDENT';
    return _supabaseService.castProjectVote(
      eventId: eventId,
      projectId: projectId,
      voterId: currentUser.id,
      voterRole: role,
    );
  }

  // ─── Event Management (Staff & Admin) ──────────────────────────────────────

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
    final success = await _supabaseService.createEvent(
      title: title,
      description: description,
      category: category,
      venue: venue,
      eventDate: eventDate,
      startTime: startTime,
      endTime: endTime,
      maxCapacity: maxCapacity,
      facultyCoordinators: facultyCoordinators,
      rules: rules,
    );
    if (success) {
      await syncFromSupabase();
    }
    return success;
  }

  Future<bool> deleteEvent(String eventId) async {
    final success = await _supabaseService.deleteEvent(eventId);
    if (success) {
      _events.removeWhere((e) => e.id == eventId);
      notifyListeners();
    }
    return success;
  }

  Future<List<EventRegistrationModel>> fetchEventRegistrations(String eventId) async {
    final remote = await _supabaseService.fetchEventRegistrations(eventId);
    if (remote.isNotEmpty) return remote;
    return _registrations.where((r) => r.eventId == eventId).toList();
  }

  // ─── QR Attendance (Staff & Admin Only) ────────────────────────────────────

  Future<Map<String, dynamic>> scanAndMarkAttendance({
    required String qrOrRoll,
    required String eventId,
    required String session,
  }) async {
    final result = await _supabaseService.validateAndMarkAttendanceByQr(
      qrOrRoll: qrOrRoll,
      eventId: eventId,
      session: session,
      scannedBy: currentUser.name,
    );

    if (result['success'] == true) {
      final now = DateTime.now();
      _attendanceLogs.insert(
        0,
        AttendanceLog(
          id: 'log-${now.millisecondsSinceEpoch}',
          date: 'Today',
          time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          subject: eventId,
          room: session,
          status: 'Present',
        ),
      );
      notifyListeners();
    }
    return result;
  }

  // ─── Polls (Students Vote; Staff & Admin Create; Staff CANNOT Vote) ─────────

  Future<bool> voteOnPoll(String pollId, int optionIndex) async {
    // Restriction: Staff cannot vote in polls!
    if (currentUser.isStaff) {
      debugPrint('Staff accounts are prohibited from voting in student polls.');
      return false;
    }

    final pollIndex = _polls.indexWhere((p) => p.id == pollId);
    if (pollIndex == -1) return false;

    final poll = _polls[pollIndex];
    if (poll.userVotedIndex != null) {
      poll.options[poll.userVotedIndex!].votes--;
    }
    poll.userVotedIndex = optionIndex;
    poll.options[optionIndex].votes++;
    notifyListeners();

    if (_supabaseService.isInitialized) {
      final opt = poll.options[optionIndex];
      await _supabaseService.castVote(
        pollId: pollId,
        optionId: opt.id,
        userId: currentUser.id,
      );
    }
    return true;
  }

  Future<bool> createPoll({
    required String question,
    required String description,
    required String category,
    required List<String> options,
  }) async {
    final success = await _supabaseService.createPoll(
      question: question,
      description: description,
      category: category,
      options: options,
    );
    if (success) {
      await syncFromSupabase();
    }
    return success;
  }

  // ─── Notifications & Alerts (Staff & Admin Dispatch) ───────────────────────

  Future<bool> broadcastNotice({
    required String title,
    required String message,
    String category = 'Urgent',
    String targetAudience = 'ALL',
  }) async {
    final success = await _supabaseService.broadcastNotification(
      title: title,
      message: message,
      category: category,
      targetAudience: targetAudience,
    );
    if (success) {
      await syncFromSupabase();
    }
    return success;
  }

  Future<void> markNotificationAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
      if (_supabaseService.isInitialized && currentUser.id.isNotEmpty) {
        await SupabaseService.client?.from('notification_reads').upsert({
          'id': '${id}_${currentUser.id}',
          'notification_id': id,
          'user_id': currentUser.id,
          'read_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  void markAllNotificationsAsRead() {
    for (final notif in _notifications) {
      notif.isRead = true;
    }
    notifyListeners();
  }

  void addAttendanceLog({required String subject, required String room, String status = 'Present'}) {
    final now = DateTime.now();
    _attendanceLogs.insert(
      0,
      AttendanceLog(
        id: 'log-${now.millisecondsSinceEpoch}',
        date: 'Today',
        time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        subject: subject,
        room: room,
        status: status,
      ),
    );
    notifyListeners();
  }

}

