enum UserRole { student, staff, admin }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String rollNumber;
  final UserRole role;
  final String department;
  final String academicDetails; // e.g. "B.Tech IT • 3rd Year" or "Assistant Professor"
  final String yearLevel;
  final String section;
  final String phoneNumber;
  final String status;
  final String labPassId; // QR token string for digital turnstile pass
  final String labPassRoom;
  final String labPassExpiry;
  final double cgpa;
  final int attendancePercent;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.rollNumber,
    required this.role,
    required this.department,
    required this.academicDetails,
    this.yearLevel = "3rd Year",
    this.section = "B",
    this.phoneNumber = "",
    this.status = "ACTIVE",
    this.labPassId = "ELITE_QR_PASS",
    this.labPassRoom = "IT Lab & Turnstile Gate #2",
    this.labPassExpiry = "AY 2026-2027",
    this.cgpa = 8.94,
    this.attendancePercent = 88,
  });

  factory UserModel.empty() => UserModel(
        id: '',
        name: '',
        email: '',
        rollNumber: '',
        role: UserRole.student,
        department: 'Information Technology',
        academicDetails: '',
        status: 'INACTIVE',
        cgpa: 0,
        attendancePercent: 0,
      );

  bool get isStudent => role == UserRole.student;
  bool get isStaff => role == UserRole.staff;
  bool get isAdmin => role == UserRole.admin;
}

class EventModel {
  final String id;
  final String title;
  final String description;
  final String category; // Workshop, Hackathon, Technical, Creative, Cultural
  final String dateMonth; // "OCT"
  final String dateDay; // "24"
  final String time;
  final String venue;
  final String speaker;
  int seatsLeft;
  final int totalSeats;
  bool isRegistered;
  final String rules;
  final String status; // OPEN, CLOSED
  final bool isTeamEvent;
  final int minTeamSize;
  final int maxTeamSize;
  final bool isProjectSubmissionEnabled;
  final DateTime? projectSubmissionDeadline;
  final bool isVotingEnabled;
  final DateTime? votingStart;
  final DateTime? votingEnd;
  final List<String> votingEligibleRoles;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.dateMonth,
    required this.dateDay,
    required this.time,
    required this.venue,
    required this.speaker,
    required this.seatsLeft,
    required this.totalSeats,
    this.isRegistered = false,
    this.rules = "",
    this.status = "OPEN",
    this.isTeamEvent = false,
    this.minTeamSize = 1,
    this.maxTeamSize = 1,
    this.isProjectSubmissionEnabled = false,
    this.projectSubmissionDeadline,
    this.isVotingEnabled = false,
    this.votingStart,
    this.votingEnd,
    this.votingEligibleRoles = const ['STUDENT', 'STAFF'],
  });
}

class TeamMemberInfo {
  final String studentId;
  final String studentRoll;
  final String studentName;
  final String studentEmail;
  final String studentDept;
  final String studentYear;
  final bool isLeader;

  TeamMemberInfo({
    required this.studentId,
    required this.studentRoll,
    required this.studentName,
    required this.studentEmail,
    required this.studentDept,
    this.studentYear = "3rd Year",
    this.isLeader = false,
  });

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'studentRoll': studentRoll,
    'studentName': studentName,
    'studentEmail': studentEmail,
    'studentDept': studentDept,
    'studentYear': studentYear,
    'isLeader': isLeader,
  };

  factory TeamMemberInfo.fromJson(Map<String, dynamic> json) => TeamMemberInfo(
    studentId: json['studentId']?.toString() ?? '',
    studentRoll: json['studentRoll']?.toString() ?? '',
    studentName: json['studentName']?.toString() ?? '',
    studentEmail: json['studentEmail']?.toString() ?? '',
    studentDept: json['studentDept']?.toString() ?? 'IT',
    studentYear: json['studentYear']?.toString() ?? '3rd Year',
    isLeader: json['isLeader'] == true,
  );
}

class EventRegistrationModel {
  final String id;
  final String eventId;
  final bool isTeam;
  final String? teamName;
  final String studentId;
  final String studentRoll;
  final String studentName;
  final String studentEmail;
  final String studentDept;
  final String studentYear;
  final List<TeamMemberInfo> members;
  final String status;
  final String registeredAt;

  EventRegistrationModel({
    required this.id,
    required this.eventId,
    this.isTeam = false,
    this.teamName,
    required this.studentId,
    required this.studentRoll,
    required this.studentName,
    required this.studentEmail,
    this.studentDept = "Information Technology",
    required this.studentYear,
    this.members = const [],
    this.status = "CONFIRMED",
    required this.registeredAt,
  });

  /// Check if a given student roll or email is part of this registration
  bool containsStudent(String rollOrEmail) {
    final q = rollOrEmail.trim().toLowerCase();
    if (studentRoll.toLowerCase() == q || studentEmail.toLowerCase() == q) return true;
    return members.any((m) =>
        m.studentRoll.toLowerCase() == q ||
        m.studentEmail.toLowerCase() == q ||
        m.studentId.toLowerCase() == q);
  }

  bool isLeader(String rollOrEmail) {
    final q = rollOrEmail.trim().toLowerCase();
    return studentRoll.toLowerCase() == q || studentEmail.toLowerCase() == q;
  }
}

class SubjectAttendance {
  final String code;
  final String title;
  final int attended;
  final int total;
  final String faculty;

  SubjectAttendance({
    required this.code,
    required this.title,
    required this.attended,
    required this.total,
    required this.faculty,
  });

  double get percentage => total == 0 ? 0 : (attended / total) * 100;
}

class AttendanceLog {
  final String id;
  final String date;
  final String time;
  final String subject;
  final String room;
  final String status; // Present, Late, Excused

  AttendanceLog({
    required this.id,
    required this.date,
    required this.time,
    required this.subject,
    required this.room,
    required this.status,
  });
}

class PollOption {
  final String id;
  final String text;
  int votes;
  final String? imageUrl;
  final String? description;

  PollOption({
    required this.id,
    required this.text,
    required this.votes,
    this.imageUrl,
    this.description,
  });
}

class PollModel {
  final String id;
  final String question;
  final String description;
  final String category;
  final List<PollOption> options;
  int? userVotedIndex;
  final String expiresText;
  final String status; // OPEN, CLOSED

  PollModel({
    required this.id,
    required this.question,
    required this.description,
    required this.category,
    required this.options,
    this.userVotedIndex,
    required this.expiresText,
    this.status = "OPEN",
  });

  int get totalVotes => options.fold(0, (sum, opt) => sum + opt.votes);
}

class LiveLeaderboardEntry {
  final int rank;
  final String title;
  final String participant;
  final String rollNumber;
  final String scoreOrTime;
  final String status; // Winner, Running, Evaluated

  LiveLeaderboardEntry({
    required this.rank,
    required this.title,
    required this.participant,
    required this.rollNumber,
    required this.scoreOrTime,
    required this.status,
  });
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String timeAgo;
  final String category; // Urgent, Academic, System, Event
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.category,
    this.isRead = false,
  });
}

class ProjectSubmissionModel {
  final String id;
  final String eventId;
  final String registrationId;
  final String teamName;
  final String leaderId;
  final String leaderName;
  final String projectName;
  final String shortDescription;
  final String detailedDescription;
  final List<String> technologies;
  final String? repoUrl;
  final String? demoUrl;
  final String? documentationUrl;
  final String? presentationUrl;
  final String? imageUrl;
  final String status; // PENDING, PUBLISHED, REJECTED
  final int voteCount;
  final String createdAt;
  final String updatedAt;

  ProjectSubmissionModel({
    required this.id,
    required this.eventId,
    required this.registrationId,
    required this.teamName,
    required this.leaderId,
    required this.leaderName,
    required this.projectName,
    this.shortDescription = '',
    this.detailedDescription = '',
    this.technologies = const [],
    this.repoUrl,
    this.demoUrl,
    this.documentationUrl,
    this.presentationUrl,
    this.imageUrl,
    this.status = 'PENDING',
    this.voteCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPublished => status.toUpperCase() == 'PUBLISHED';

  factory ProjectSubmissionModel.fromJson(Map<String, dynamic> json) {
    List<String> techList = [];
    if (json['technologies'] is List) {
      techList = (json['technologies'] as List).map((e) => e.toString()).toList();
    }

    return ProjectSubmissionModel(
      id: json['id']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? '',
      registrationId: json['registration_id']?.toString() ?? '',
      teamName: json['team_name']?.toString() ?? '',
      leaderId: json['leader_id']?.toString() ?? '',
      leaderName: json['leader_name']?.toString() ?? '',
      projectName: json['project_name']?.toString() ?? '',
      shortDescription: json['short_description']?.toString() ?? '',
      detailedDescription: json['detailed_description']?.toString() ?? '',
      technologies: techList,
      repoUrl: json['repo_url']?.toString(),
      demoUrl: json['demo_url']?.toString(),
      documentationUrl: json['documentation_url']?.toString(),
      presentationUrl: json['presentation_url']?.toString(),
      imageUrl: json['image_url']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'event_id': eventId,
    'registration_id': registrationId,
    'team_name': teamName,
    'leader_id': leaderId,
    'leader_name': leaderName,
    'project_name': projectName,
    'short_description': shortDescription,
    'detailed_description': detailedDescription,
    'technologies': technologies,
    'repo_url': repoUrl,
    'demo_url': demoUrl,
    'documentation_url': documentationUrl,
    'presentation_url': presentationUrl,
    'image_url': imageUrl,
    'status': status,
    'vote_count': voteCount,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

class ProjectVoteModel {
  final String id;
  final String eventId;
  final String projectId;
  final String voterId;
  final String voterRole;
  final String votedAt;

  ProjectVoteModel({
    required this.id,
    required this.eventId,
    required this.projectId,
    required this.voterId,
    required this.voterRole,
    required this.votedAt,
  });

  factory ProjectVoteModel.fromJson(Map<String, dynamic> json) => ProjectVoteModel(
    id: json['id']?.toString() ?? '',
    eventId: json['event_id']?.toString() ?? '',
    projectId: json['project_id']?.toString() ?? '',
    voterId: json['voter_id']?.toString() ?? '',
    voterRole: json['voter_role']?.toString() ?? 'STUDENT',
    votedAt: json['voted_at']?.toString() ?? '',
  );
}

