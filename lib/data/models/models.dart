// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import '../../core/utils/geo.dart';

// ------------------------------------------------------------------ helpers

Map<String, Object?> _map(Object? o) => (o! as Map).cast<String, Object?>();
List<Object?> _list(Object? o) => (o as List?)?.cast<Object?>() ?? const [];
DateTime _time(Object? o) => DateTime.fromMillisecondsSinceEpoch(o! as int);
int _ms(DateTime t) => t.millisecondsSinceEpoch;

// -------------------------------------------------------------------- roles

enum Role {
  // Shown before we know someone's group; once signed in, roleTitle() gives
  // their group's own word (Student, Employee, Teacher, Team lead…).
  student('Student or member', '/student'),
  educator('Teacher or team lead', '/educator'),
  ngo('NGO partner', '/ngo'),
  manager('Admin', '/manager');

  const Role(this.label, this.home);
  final String label;
  final String home;
}

// ------------------------------------------------------------- identities

/// The identity attached to an authenticated session.
class SessionUser {
  const SessionUser({
    required this.id,
    required this.role,
    required this.name,
    this.email,
    this.classCode,
    this.school,
    this.ngoId,
  });

  final String id;
  final Role role;
  final String name;
  final String? email;
  final String? classCode;
  final String? school;
  final String? ngoId;

  String get firstName => name.split(' ').firstWhere((p) => p.length > 2 && !p.endsWith('.'), orElse: () => name);
}

/// Educators, NGO desks and managers sign in with a secret; their records
/// store only a PBKDF2 hash, never the secret itself.
class Account {
  const Account({
    required this.id,
    required this.role,
    required this.name,
    required this.loginId,
    required this.secretHash,
    this.school,
    this.classCode,
    this.ngoId,
    this.createdAt,
  });

  final String id;
  final Role role;
  final String name;

  /// Email for educators and managers, NGO id for NGO desks.
  final String loginId;
  final String secretHash;
  final String? school;
  final String? classCode;
  final String? ngoId;
  final DateTime? createdAt;

  SessionUser toSession() => SessionUser(
        id: id,
        role: role,
        name: name,
        email: role == Role.ngo ? null : loginId,
        classCode: classCode,
        school: school,
        ngoId: ngoId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'role': role.name,
        'name': name,
        'loginId': loginId,
        'secretHash': secretHash,
        'school': school,
        'classCode': classCode,
        'ngoId': ngoId,
        'createdAt': createdAt == null ? null : _ms(createdAt!),
      };

  factory Account.fromJson(Map<String, Object?> j) => Account(
        id: j['id']! as String,
        role: Role.values.byName(j['role']! as String),
        name: j['name']! as String,
        loginId: j['loginId']! as String,
        secretHash: j['secretHash']! as String,
        school: j['school'] as String?,
        classCode: j['classCode'] as String?,
        ngoId: j['ngoId'] as String?,
        createdAt: j['createdAt'] == null ? null : _time(j['createdAt']),
      );
}

class StudentProfile {
  StudentProfile({
    required this.id,
    required this.name,
    required this.classCode,
    this.phone,
    this.pinHash,
    this.importedModules = 0,
    this.importedScorePct = 0,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  final String id;
  final String name;
  String classCode;
  final String? phone;

  /// Set the first time the student signs in ("claims" the profile).
  String? pinHash;

  /// Progress carried over from the previous app version.
  final int importedModules;
  final int importedScorePct;
  final DateTime joinedAt;

  bool get isClaimed => pinHash != null;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'classCode': classCode,
        'phone': phone,
        'pinHash': pinHash,
        'importedModules': importedModules,
        'importedScorePct': importedScorePct,
        'joinedAt': _ms(joinedAt),
      };

  factory StudentProfile.fromJson(Map<String, Object?> j) => StudentProfile(
        id: j['id']! as String,
        name: j['name']! as String,
        classCode: j['classCode']! as String,
        phone: j['phone'] as String?,
        pinHash: j['pinHash'] as String?,
        importedModules: (j['importedModules'] as int?) ?? 0,
        importedScorePct: (j['importedScorePct'] as int?) ?? 0,
        joinedAt: j['joinedAt'] == null ? null : _time(j['joinedAt']),
      );
}

/// The kind of group a class, team or group belongs to. AquaAware works for
/// any of them, and the words the app shows follow the kind: a school class
/// has a teacher and students, an office team has a team lead and employees.
///
/// Inside the code the member role is still called `student` and the leader
/// `educator`, and every group is a `ClassRoom` with a `classCode`; only the
/// words people see change.
enum InstitutionKind {
  school(
    label: 'School',
    noun: 'school',
    atPlace: 'at school',
    leaderTitle: 'Teacher',
    leaderNoun: 'teacher',
    memberTitle: 'Student',
    membersNoun: 'students',
    groupTitle: 'Class',
    groupNoun: 'class',
    holdsNoticesDuringDay: true,
    dayEndHour: 15,
  ),
  college(
    label: 'College',
    noun: 'college',
    atPlace: 'at college',
    leaderTitle: 'Faculty',
    leaderNoun: 'faculty',
    memberTitle: 'Student',
    membersNoun: 'students',
    groupTitle: 'Class',
    groupNoun: 'class',
    holdsNoticesDuringDay: true,
    dayEndHour: 15,
  ),
  office(
    label: 'Office',
    noun: 'office',
    atPlace: 'at work',
    leaderTitle: 'Team lead',
    leaderNoun: 'team lead',
    memberTitle: 'Employee',
    membersNoun: 'employees',
    groupTitle: 'Team',
    groupNoun: 'team',
    holdsNoticesDuringDay: false,
    dayEndHour: 18,
  ),
  community(
    label: 'Community',
    noun: 'community',
    atPlace: 'out in your community',
    leaderTitle: 'Organiser',
    leaderNoun: 'organiser',
    memberTitle: 'Member',
    membersNoun: 'members',
    groupTitle: 'Group',
    groupNoun: 'group',
    holdsNoticesDuringDay: false,
    dayEndHour: 18,
  );

  const InstitutionKind({
    required this.label,
    required this.noun,
    required this.atPlace,
    required this.leaderTitle,
    required this.leaderNoun,
    required this.memberTitle,
    required this.membersNoun,
    required this.groupTitle,
    required this.groupNoun,
    required this.holdsNoticesDuringDay,
    required this.dayEndHour,
  });

  /// "School", "Office", for headings and buttons.
  final String label;

  /// "school", "office", inside sentences ("the school tank").
  final String noun;

  /// Where members probably are during the day ("at school", "at work").
  final String atPlace;

  /// "Teacher", "Faculty", "Team lead", "Organiser": who runs the group.
  final String leaderTitle;

  /// The same inside sentences ("ask your team lead").
  final String leaderNoun;

  /// "Student", "Employee", "Member".
  final String memberTitle;

  /// "students", "employees", "members".
  final String membersNoun;

  /// "Class", "Team", "Group".
  final String groupTitle;

  /// "class", "team", "group" ("your team").
  final String groupNoun;

  /// Schools and colleges hold non-urgent notices during the school day
  /// (Q2 quiet hours); offices and communities get them straight away.
  final bool holdsNoticesDuringDay;

  /// The hour the day's activities end; the daily water bonus opens then.
  final int dayEndHour;

  /// "Class code", "Team code", "Group code".
  String get codeLabel => '$groupTitle code';

  /// "student", "employee", "member".
  String get memberNoun => memberTitle.toLowerCase();

  /// "Students", "Employees", "Members".
  String get membersTitle => '${membersNoun[0].toUpperCase()}${membersNoun.substring(1)}';

  /// "3 pm", "6 pm".
  String get dayEndLabel => dayEndHour > 12 ? '${dayEndHour - 12} pm' : '$dayEndHour am';

  /// Older saved data has no kind; those classes are schools.
  static InstitutionKind parse(Object? value) => values.asNameMap()[value] ?? InstitutionKind.school;
}

/// The title a signed-in person sees for their own role, in their group's words.
String roleTitle(Role role, InstitutionKind kind) => switch (role) {
      Role.student => kind.memberTitle,
      Role.educator => kind.leaderTitle,
      Role.ngo || Role.manager => role.label,
    };

class ClassRoom {
  const ClassRoom({
    required this.code,
    required this.school,
    required this.educatorId,
    required this.city,
    this.kind = InstitutionKind.school,
  });
  final String code;

  /// The name of the school, college, office or community group.
  final String school;
  final String educatorId;
  final String city;
  final InstitutionKind kind;

  Map<String, Object?> toJson() =>
      {'code': code, 'school': school, 'educatorId': educatorId, 'city': city, 'kind': kind.name};
  factory ClassRoom.fromJson(Map<String, Object?> j) => ClassRoom(
        code: j['code']! as String,
        school: j['school']! as String,
        educatorId: j['educatorId']! as String,
        city: j['city']! as String,
        kind: InstitutionKind.parse(j['kind']),
      );
}

// --------------------------------------------------------------- learning

enum SlideArtKind { stat, icons, bins }

/// A drawn illustration for a lesson slide.
///
/// The first version showed random stock photos (picsum.photos) whose alt
/// text described scenes that were never in the picture. These are drawn
/// from the lesson itself — a key number, a few topic icons, or the four
/// segregation bins — so they always match, work offline and cost no data.
/// They are decorative: the slide text carries the meaning for screen readers.
class SlideArt {
  /// A headline number such as "163M" with a short caption.
  const SlideArt.stat(String this.stat, String this.caption, {this.icon = 'drop'})
      : kind = SlideArtKind.stat,
        icons = const [];

  /// A row of 2–5 topic icons (keys resolved by the UI).
  const SlideArt.icons(this.icons)
      : kind = SlideArtKind.icons,
        stat = null,
        caption = null,
        icon = 'drop';

  /// The green / blue / red / yellow bins from module B.
  const SlideArt.bins()
      : kind = SlideArtKind.bins,
        stat = null,
        caption = null,
        icon = 'drop',
        icons = const [];

  final SlideArtKind kind;
  final String? stat;
  final String? caption;
  final String icon;
  final List<String> icons;
}

class Slide {
  const Slide({required this.title, required this.text, required this.art});
  final String title;
  final String text;
  final SlideArt art;
}

class LearningModule {
  const LearningModule({
    required this.id,
    required this.title,
    required this.summary,
    required this.minutes,
    required this.slides,
    this.activity,
  });
  final String id;
  final String title;
  final String summary;
  final int minutes;
  final List<Slide> slides;
  final String? activity;
}

class QuizQuestion {
  const QuizQuestion(this.prompt, this.options, this.correct, {this.explain});
  final String prompt;
  final List<String> options;
  final int correct;
  final String? explain;
}

class Reward {
  const Reward({required this.id, required this.name, required this.points, required this.blurb});
  final String id;
  final String name;
  final int points;
  final String blurb;
}

class GalleryItem {
  const GalleryItem({required this.id, required this.imageSeed, required this.title, required this.description});
  final String id;
  final String imageSeed;
  final String title;
  final String description;
}

enum BinColor { green, blue, red, yellow }

class SortItem {
  const SortItem(this.name, this.bin, this.why);
  final String name;
  final BinColor bin;
  final String why;
}

// -------------------------------------------------------------- community

class NgoActivity {
  const NgoActivity({
    required this.id,
    required this.name,
    required this.date,
    required this.participants,
    this.place,
    this.ngoId,
  });
  final String id;
  final String name;
  final DateTime date;

  /// Volunteers registered before the app (seed data). Check-ins made
  /// through the app are counted separately from the ledger.
  final int participants;
  final String? place;

  /// Set for activities an NGO desk created in the app.
  final String? ngoId;

  bool isPast([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(date.year, date.month, date.day).isBefore(DateTime(n.year, n.month, n.day));
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'date': _ms(date),
        'participants': participants,
        'place': place,
        'ngoId': ngoId,
      };

  factory NgoActivity.fromJson(Map<String, Object?> j) => NgoActivity(
        id: j['id']! as String,
        name: j['name']! as String,
        date: _time(j['date']),
        participants: (j['participants'] as int?) ?? 0,
        place: j['place'] as String?,
        ngoId: j['ngoId'] as String?,
      );
}

class Ngo {
  const Ngo({
    required this.id,
    required this.name,
    required this.focus,
    required this.address,
    required this.phone,
    required this.email,
    required this.location,
    required this.area,
    required this.activities,
  });
  final String id;
  final String name;
  final String focus;
  final String address;
  final String phone;
  final String email;
  final GeoPoint location;
  final String area;
  final List<NgoActivity> activities;

  String get shortName {
    final m = RegExp(r'\(([^)]+)\)').firstMatch(name);
    if (m != null) return m.group(1)!;
    return name.split(' ').where((w) => w.isNotEmpty && w[0] == w[0].toUpperCase()).map((w) => w[0]).join();
  }
}

class Collector {
  const Collector({
    required this.id,
    required this.name,
    required this.phone,
    required this.wasteType,
    required this.available,
    required this.location,
    required this.area,
  });
  final String id;
  final String name;
  final String phone;
  final String wasteType;
  final bool available;
  final GeoPoint location;
  final String area;
}

/// A school, college or university shown on the eco-map.
class SchoolSite {
  const SchoolSite({required this.id, required this.name, required this.location, this.type = 'School'});
  final String id;
  final String name;
  final GeoPoint location;

  /// "School", "College" or "University", shown under the name.
  final String type;
}

// --------------------------------------------------------------- activity

class Announcement {
  Announcement({
    required this.id,
    required this.message,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.sentAt,
    required this.audience,
    required this.audienceSize,
    this.urgent = false,
    Set<String>? completedBy,
  }) : completedBy = completedBy ?? <String>{};

  final String id;
  final String message;
  final String senderId;
  final String senderName;
  final Role senderRole;
  final DateTime sentAt;

  /// A class code, or "ALL" for every student.
  final String audience;
  final int audienceSize;

  /// Q2 — non-urgent notices are held quietly during class hours (8 am–3 pm).
  final bool urgent;
  final Set<String> completedBy;

  int get points => senderRole == Role.ngo ? 10 : 5;

  bool reaches(String? classCode) => audience == 'ALL' || audience == classCode;

  Map<String, Object?> toJson() => {
        'id': id,
        'message': message,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole.name,
        'sentAt': _ms(sentAt),
        'audience': audience,
        'audienceSize': audienceSize,
        'urgent': urgent,
        'completedBy': completedBy.toList(),
      };

  factory Announcement.fromJson(Map<String, Object?> j) => Announcement(
        id: j['id']! as String,
        message: j['message']! as String,
        senderId: j['senderId']! as String,
        senderName: j['senderName']! as String,
        senderRole: Role.values.byName(j['senderRole']! as String),
        sentAt: _time(j['sentAt']),
        audience: j['audience']! as String,
        audienceSize: (j['audienceSize'] as int?) ?? 0,
        urgent: (j['urgent'] as bool?) ?? false,
        completedBy: _list(j['completedBy']).cast<String>().toSet(),
      );
}

class DirectMessage {
  DirectMessage({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.fromRole,
    required this.toId,
    required this.toName,
    required this.body,
    required this.sentAt,
    this.read = false,
  });

  final String id;
  final String fromId;
  final String fromName;
  final Role fromRole;
  final String toId;
  final String toName;
  final String body;
  final DateTime sentAt;
  bool read;

  Map<String, Object?> toJson() => {
        'id': id,
        'fromId': fromId,
        'fromName': fromName,
        'fromRole': fromRole.name,
        'toId': toId,
        'toName': toName,
        'body': body,
        'sentAt': _ms(sentAt),
        'read': read,
      };

  factory DirectMessage.fromJson(Map<String, Object?> j) => DirectMessage(
        id: j['id']! as String,
        fromId: j['fromId']! as String,
        fromName: j['fromName']! as String,
        fromRole: Role.values.byName(j['fromRole']! as String),
        toId: j['toId']! as String,
        toName: j['toName']! as String,
        body: j['body']! as String,
        sentAt: _time(j['sentAt']),
        read: (j['read'] as bool?) ?? false,
      );
}

enum ResourceKind { pdf, slides, document, other }

class Resource {
  Resource({
    required this.id,
    required this.name,
    required this.kind,
    required this.classCode,
    required this.uploaderName,
    required this.addedAt,
    this.sizeBytes,
    this.localPath,
    Set<String>? seenBy,
  }) : seenBy = seenBy ?? <String>{};

  final String id;
  final String name;
  final ResourceKind kind;
  final String classCode;
  final String uploaderName;
  final DateTime addedAt;
  final int? sizeBytes;
  final String? localPath;
  final Set<String> seenBy;

  static ResourceKind kindFor(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (ext == 'pdf') return ResourceKind.pdf;
    if (ext == 'ppt' || ext == 'pptx' || ext == 'key' || ext == 'odp') return ResourceKind.slides;
    if (ext == 'doc' || ext == 'docx' || ext == 'odt' || ext == 'txt') return ResourceKind.document;
    return ResourceKind.other;
  }

  String get kindLabel => switch (kind) {
        ResourceKind.pdf => 'PDF',
        ResourceKind.slides => 'Slides',
        ResourceKind.document => 'Document',
        ResourceKind.other => 'File',
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'classCode': classCode,
        'uploaderName': uploaderName,
        'addedAt': _ms(addedAt),
        'sizeBytes': sizeBytes,
        'localPath': localPath,
        'seenBy': seenBy.toList(),
      };

  factory Resource.fromJson(Map<String, Object?> j) => Resource(
        id: j['id']! as String,
        name: j['name']! as String,
        kind: ResourceKind.values.byName(j['kind']! as String),
        classCode: j['classCode']! as String,
        uploaderName: j['uploaderName']! as String,
        addedAt: _time(j['addedAt']),
        sizeBytes: j['sizeBytes'] as int?,
        localPath: j['localPath'] as String?,
        seenBy: _list(j['seenBy']).cast<String>().toSet(),
      );
}

enum PickupStatus { onTheWay, handedOver, cancelled }

class PickupRequest {
  PickupRequest({
    required this.id,
    required this.studentId,
    required this.collectorId,
    required this.requestedAt,
    required this.etaMinutes,
    required this.distanceMeters,
    this.status = PickupStatus.onTheWay,
    this.closedAt,
  });

  final String id;
  final String studentId;
  final String collectorId;
  final DateTime requestedAt;
  final int etaMinutes;
  final double distanceMeters;
  PickupStatus status;
  DateTime? closedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'studentId': studentId,
        'collectorId': collectorId,
        'requestedAt': _ms(requestedAt),
        'etaMinutes': etaMinutes,
        'distanceMeters': distanceMeters,
        'status': status.name,
        'closedAt': closedAt == null ? null : _ms(closedAt!),
      };

  factory PickupRequest.fromJson(Map<String, Object?> j) => PickupRequest(
        id: j['id']! as String,
        studentId: j['studentId']! as String,
        collectorId: j['collectorId']! as String,
        requestedAt: _time(j['requestedAt']),
        etaMinutes: j['etaMinutes']! as int,
        distanceMeters: (j['distanceMeters']! as num).toDouble(),
        status: PickupStatus.values.byName(j['status']! as String),
        closedAt: j['closedAt'] == null ? null : _time(j['closedAt']),
      );
}

enum ClaimStatus { pending, redeemed, cancelled }

class RewardClaim {
  RewardClaim({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rewardId,
    required this.rewardName,
    required this.points,
    required this.token,
    required this.nonce,
    required this.createdAt,
    required this.expiresAt,
    this.status = ClaimStatus.pending,
    this.redeemedAt,
    this.redeemedBy,
    this.locationVerified = false,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String rewardId;
  final String rewardName;
  final int points;
  final String token;
  final String nonce;
  final DateTime createdAt;
  final DateTime expiresAt;
  ClaimStatus status;
  DateTime? redeemedAt;
  String? redeemedBy;
  bool locationVerified;

  bool isExpired([DateTime? now]) => (now ?? DateTime.now()).isAfter(expiresAt);
  bool get isOpen => status == ClaimStatus.pending && !isExpired();

  Map<String, Object?> toJson() => {
        'id': id,
        'studentId': studentId,
        'studentName': studentName,
        'rewardId': rewardId,
        'rewardName': rewardName,
        'points': points,
        'token': token,
        'nonce': nonce,
        'createdAt': _ms(createdAt),
        'expiresAt': _ms(expiresAt),
        'status': status.name,
        'redeemedAt': redeemedAt == null ? null : _ms(redeemedAt!),
        'redeemedBy': redeemedBy,
        'locationVerified': locationVerified,
      };

  factory RewardClaim.fromJson(Map<String, Object?> j) => RewardClaim(
        id: j['id']! as String,
        studentId: j['studentId']! as String,
        studentName: j['studentName']! as String,
        rewardId: j['rewardId']! as String,
        rewardName: j['rewardName']! as String,
        points: j['points']! as int,
        token: j['token']! as String,
        nonce: j['nonce']! as String,
        createdAt: _time(j['createdAt']),
        expiresAt: _time(j['expiresAt']),
        status: ClaimStatus.values.byName(j['status']! as String),
        redeemedAt: j['redeemedAt'] == null ? null : _time(j['redeemedAt']),
        redeemedBy: j['redeemedBy'] as String?,
        locationVerified: (j['locationVerified'] as bool?) ?? false,
      );
}

/// Per-student learning progress (points live in the ledger, not here).
class StudentProgress {
  StudentProgress({Set<String>? modulesDone, Map<String, int>? quizBest, Set<String>? activeDays})
      : modulesDone = modulesDone ?? <String>{},
        quizBest = quizBest ?? <String, int>{},
        activeDays = activeDays ?? <String>{};

  final Set<String> modulesDone;

  /// moduleId → best number of correct answers.
  final Map<String, int> quizBest;

  /// yyyy-mm-dd keys, used for the streak.
  final Set<String> activeDays;

  Map<String, Object?> toJson() => {
        'modulesDone': modulesDone.toList(),
        'quizBest': quizBest,
        'activeDays': activeDays.toList(),
      };

  factory StudentProgress.fromJson(Map<String, Object?> j) => StudentProgress(
        modulesDone: _list(j['modulesDone']).cast<String>().toSet(),
        quizBest: (j['quizBest'] as Map?)?.cast<String, int>() ?? <String, int>{},
        activeDays: _list(j['activeDays']).cast<String>().toSet(),
      );
}

class ActivityLogEntry {
  const ActivityLogEntry({required this.at, required this.actor, required this.action});
  final DateTime at;
  final String actor;
  final String action;

  Map<String, Object?> toJson() => {'at': _ms(at), 'actor': actor, 'action': action};
  factory ActivityLogEntry.fromJson(Map<String, Object?> j) =>
      ActivityLogEntry(at: _time(j['at']), actor: j['actor']! as String, action: j['action']! as String);
}

/// Exposed for repositories that persist lists of models.
List<T> decodeList<T>(Object? raw, T Function(Map<String, Object?>) fromJson) {
  final out = <T>[];
  for (final e in _list(raw)) {
    try {
      out.add(fromJson(_map(e)));
    } catch (_) {
      // Skip malformed rows instead of crashing the whole app.
    }
  }
  return out;
}
