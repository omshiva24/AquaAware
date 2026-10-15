// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/net/sync_service.dart';
import '../core/security/crypto_service.dart';
import '../core/security/input_rules.dart';
import '../core/security/ledger.dart';
import '../core/security/secure_vault.dart';
import '../core/security/signed_token.dart';
import '../core/utils/format.dart';
import '../core/utils/geo.dart';
import 'models/models.dart';
import 'points_rules.dart';
import 'seed/community_seed.dart';
import 'seed/content_seed.dart';

/// Raised when a request is refused for a reason the person can act on.
class ActionRefused implements Exception {
  const ActionRefused(this.message);
  final String message;
  @override
  String toString() => message;
}

class StudentSummary {
  const StudentSummary({
    required this.profile,
    required this.points,
    required this.modulesDone,
    required this.avgScorePct,
    required this.lastActive,
  });
  final StudentProfile profile;
  final int points;
  final int modulesDone;
  final int avgScorePct;
  final DateTime? lastActive;

  bool get atRisk => modulesDone < 3 || avgScorePct < 70;
  String get riskReason {
    if (modulesDone < 3 && avgScorePct < 70) return 'Few modules and low quiz scores';
    if (modulesDone < 3) return 'Only $modulesDone of 6 modules done';
    return 'Quiz average $avgScorePct%';
  }
}

class RedeemResult {
  const RedeemResult({required this.claim, required this.studentName});
  final RewardClaim claim;
  final String studentName;
}

class _LoginGuard {
  _LoginGuard({this.failures = 0, this.lockedUntil});
  int failures;
  DateTime? lockedUntil;

  Map<String, Object?> toJson() => {'f': failures, 'u': lockedUntil?.millisecondsSinceEpoch};
  factory _LoginGuard.fromJson(Map<String, Object?> j) => _LoginGuard(
        failures: (j['f'] as int?) ?? 0,
        lockedUntil: j['u'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['u']! as int),
      );
}

/// The single source of truth for app data. Everything is persisted through
/// the encrypted [SecureVault]; anything a server should know about is also
/// queued in the [SyncService] outbox.
///
/// Q6 — data is partitioned by class code: educators only ever query their
/// own class, and announcements carry an explicit audience.
class AppStore extends ChangeNotifier {
  AppStore(this._vault, this._sync) : signer = TokenSigner(_vault.macKey);

  final SecureVault _vault;
  final SyncService _sync;
  final TokenSigner signer;

  List<Account> accounts = [];
  List<StudentProfile> students = [];
  List<ClassRoom> classes = [];
  List<Announcement> announcements = [];
  List<DirectMessage> messages = [];
  List<Resource> resources = [];
  List<PickupRequest> pickups = [];
  List<RewardClaim> claims = [];
  Map<String, StudentProgress> progress = {};
  List<LedgerEntry> ledger = [];
  Set<String> usedNonces = {};
  List<ActivityLogEntry> activity = [];

  /// Events NGO desks scheduled in the app (seeded events live in [CommunitySeed]).
  List<NgoActivity> customActivities = [];
  final Map<String, _LoginGuard> _guards = {};

  /// -1 when the ledger chain verifies; otherwise the first broken index.
  int ledgerBrokenAt = -1;
  bool get ledgerIntact => ledgerBrokenAt < 0;

  Future<void> _lock = Future<void>.value();

  // ================================================================ load ===

  Future<void> load() async {
    final seedVersion = await _vault.readJson('seedVersion');
    accounts = decodeList(await _vault.readJson('accounts'), Account.fromJson);
    // Data from before version 2 is reset; version 2 data is kept and only
    // gains the classes, accounts and students added since (_addNewSeedData).
    final keep = seedVersion is int && seedVersion >= 2 && accounts.isNotEmpty;
    if (!keep) {
      await _seed();
    } else {
      students = decodeList(await _vault.readJson('students'), StudentProfile.fromJson);
      classes = decodeList(await _vault.readJson('classes'), ClassRoom.fromJson);
      announcements = decodeList(await _vault.readJson('announcements'), Announcement.fromJson);
      messages = decodeList(await _vault.readJson('messages'), DirectMessage.fromJson);
      resources = decodeList(await _vault.readJson('resources'), Resource.fromJson);
      pickups = decodeList(await _vault.readJson('pickups'), PickupRequest.fromJson);
      claims = decodeList(await _vault.readJson('claims'), RewardClaim.fromJson);
      ledger = decodeList(await _vault.readJson('ledger'), LedgerEntry.fromJson);
      activity = decodeList(await _vault.readJson('activity'), ActivityLogEntry.fromJson);
      customActivities = decodeList(await _vault.readJson('ngoActivities'), NgoActivity.fromJson);
      final p = await _vault.readJson('progress');
      progress = {
        if (p is Map)
          for (final e in p.entries)
            e.key as String: StudentProgress.fromJson((e.value as Map).cast<String, Object?>()),
      };
      final n = await _vault.readJson('nonces');
      usedNonces = n is List ? n.cast<String>().toSet() : <String>{};
      final g = await _vault.readJson('loginGuards');
      if (g is Map) {
        for (final e in g.entries) {
          _guards[e.key as String] = _LoginGuard.fromJson((e.value as Map).cast<String, Object?>());
        }
      }
      if (seedVersion != CommunitySeed.version) await _addNewSeedData();
    }
    ledgerBrokenAt = await LedgerChain.firstBrokenIndex(ledger, _vault.macKey);
    notifyListeners();
  }

  /// Wipes everything and re-creates the demo data.
  Future<void> resetDemoData() async {
    await _vault.wipeData();
    _guards.clear();
    await _seed();
    ledgerBrokenAt = -1;
    notifyListeners();
  }

  /// Adds seed classes, accounts and students that this device does not have
  /// yet, without touching anything people have already done.
  Future<void> _addNewSeedData() async {
    final codes = {for (final c in classes) c.code};
    final accountIds = {for (final a in accounts) a.id};
    final studentIds = {for (final s in students) s.id};
    classes.addAll(CommunitySeed.classes.where((c) => !codes.contains(c.code)));
    accounts.addAll(CommunitySeed.accounts().where((a) => !accountIds.contains(a.id)));
    students.addAll(CommunitySeed.students().where((s) => !studentIds.contains(s.id)));
    await Future.wait([for (final slot in const ['classes', 'accounts', 'students']) _persist(slot)]);
    await _vault.writeJson('seedVersion', CommunitySeed.version);
  }

  Future<void> _seed() async {
    accounts = CommunitySeed.accounts();
    classes = List.of(CommunitySeed.classes);
    students = CommunitySeed.students();
    messages = [];
    pickups = [];
    claims = [];
    customActivities = [];
    usedNonces = {};
    progress = {};
    ledger = [];
    final now = DateTime.now();

    // Rebuild each carried-over student's history so charts and points are
    // computed from real ledger entries, not hard-coded numbers.
    const offsets = [-3, -12, 4, -15, 2, -6];
    for (var si = 0; si < students.length; si++) {
      final s = students[si];
      final pr = StudentProgress();
      for (var k = 0; k < s.importedModules && k < ContentSeed.modules.length; k++) {
        final m = ContentSeed.modules[k];
        final total = ContentSeed.quizFor(m.id).length;
        final pct = (s.importedScorePct + offsets[k]).clamp(30, 100);
        final best = (pct / 100 * total).round();
        final day = now.subtract(Duration(days: (si * 3 + k * 2) % 12, hours: (si + k) % 5));
        final at = DateTime(day.year, day.month, day.day, 10 + (si + k) % 6, (si * 7 + k * 11) % 60);
        pr.modulesDone.add(m.id);
        pr.quizBest[m.id] = best;
        pr.activeDays.add(Fmt.dayKey(at));
        ledger.add(await _sealEntry(s.id, PointRules.moduleCompleted, 'Finished "${m.title}"', 'module:${m.id}', at));
        ledger.add(await _sealEntry(s.id, best * PointRules.perCorrectAnswer, 'Quiz: ${m.title} ($best/$total)',
            'quiz:${m.id}:$best', at.add(const Duration(minutes: 12))));
      }
      progress[s.id] = pr;
    }

    announcements = [
      Announcement(
        id: 'ANN-seed-1',
        message: 'Beach clean-up at Rock Beach this Saturday, 7 am. Bring gloves and a water '
            'bottle; we will provide bags. Mark this done once you have registered.',
        senderId: 'DESK-NGO003',
        senderName: 'Community Seva Centre',
        senderRole: Role.ngo,
        sentAt: now.subtract(const Duration(hours: 5)),
        audience: 'ALL',
        audienceSize: students.length,
        completedBy: {'STU003', 'STU007', 'STU010'},
      ),
      Announcement(
        id: 'ANN-seed-2',
        message: 'Please finish module B (Waste segregation) before Friday. We will try the '
            'sorting challenge together in class.',
        senderId: 'EDU001',
        senderName: 'Mrs. Kavitha Selvaraj',
        senderRole: Role.educator,
        sentAt: now.subtract(const Duration(days: 1, hours: 2)),
        audience: 'AWA-2024-GHS',
        audienceSize: students.where((s) => s.classCode == 'AWA-2024-GHS').length,
        completedBy: {'STU001', 'STU003', 'STU005', 'STU007', 'STU009'},
      ),
    ];

    resources = [
      Resource(
        id: 'RES-seed-1',
        name: 'Rainwater harvesting at school.pdf',
        kind: ResourceKind.pdf,
        classCode: 'AWA-2024-GHS',
        uploaderName: 'Mrs. Kavitha Selvaraj',
        addedAt: now.subtract(const Duration(days: 3)),
        sizeBytes: 1240000,
      ),
      Resource(
        id: 'RES-seed-2',
        name: 'Segregation colour chart.pptx',
        kind: ResourceKind.slides,
        classCode: 'AWA-2024-GHS',
        uploaderName: 'Mrs. Kavitha Selvaraj',
        addedAt: now.subtract(const Duration(days: 6)),
        sizeBytes: 3400000,
      ),
    ];

    activity = [
      ActivityLogEntry(at: now.subtract(const Duration(hours: 5)), actor: 'Community Seva Centre', action: 'sent a broadcast to everyone'),
      ActivityLogEntry(at: now.subtract(const Duration(days: 1, hours: 2)), actor: 'Mrs. Kavitha Selvaraj', action: 'posted an announcement to AWA-2024-GHS'),
      ActivityLogEntry(at: now.subtract(const Duration(days: 3)), actor: 'Mrs. Kavitha Selvaraj', action: 'shared "Rainwater harvesting at school.pdf"'),
    ];

    await Future.wait([
      for (final slot in _allSlots) _persist(slot),
    ]);
    await _vault.writeJson('seedVersion', CommunitySeed.version);
  }

  static const _allSlots = [
    'accounts', 'students', 'classes', 'announcements', 'messages', 'resources',
    'pickups', 'claims', 'progress', 'ledger', 'nonces', 'activity', 'loginGuards', 'ngoActivities',
  ];

  Future<void> _persist(String slot) {
    final Object? value = switch (slot) {
      'accounts' => accounts.map((e) => e.toJson()).toList(),
      'students' => students.map((e) => e.toJson()).toList(),
      'classes' => classes.map((e) => e.toJson()).toList(),
      'announcements' => announcements.map((e) => e.toJson()).toList(),
      'messages' => messages.map((e) => e.toJson()).toList(),
      'resources' => resources.map((e) => e.toJson()).toList(),
      'pickups' => pickups.map((e) => e.toJson()).toList(),
      'claims' => claims.map((e) => e.toJson()).toList(),
      'progress' => {for (final e in progress.entries) e.key: e.value.toJson()},
      'ledger' => ledger.map((e) => e.toJson()).toList(),
      'nonces' => usedNonces.toList(),
      'activity' => activity.map((e) => e.toJson()).toList(),
      'loginGuards' => {for (final e in _guards.entries) e.key: e.value.toJson()},
      'ngoActivities' => customActivities.map((e) => e.toJson()).toList(),
      _ => null,
    };
    return _vault.writeJson(slot, value);
  }

  Future<void> _save(List<String> slots) async {
    await Future.wait(slots.map(_persist));
    notifyListeners();
  }

  /// Runs ledger mutations one at a time so two awards can never read the
  /// same previous hash and fork the chain.
  Future<T> _exclusive<T>(Future<T> Function() task) {
    final run = _lock.then((_) => task());
    _lock = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  void _log(String actor, String action) {
    activity.insert(0, ActivityLogEntry(at: DateTime.now(), actor: actor, action: action));
    if (activity.length > 60) activity.removeRange(60, activity.length);
  }

  String _newId(String prefix) => '$prefix-${Crypto.b64url(Crypto.randomBytes(8))}';

  // ============================================================ directory ==

  ClassRoom? classByCode(String code) {
    final c = code.trim().toUpperCase();
    for (final k in classes) {
      if (k.code == c) return k;
    }
    return null;
  }

  /// School or college, for the words shown to people in this class.
  InstitutionKind kindOf(String? classCode) =>
      classCode == null ? InstitutionKind.school : (classByCode(classCode)?.kind ?? InstitutionKind.school);

  Account? accountById(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Account? accountByLogin(Role role, String loginId) {
    final key = loginId.trim().toLowerCase();
    for (final a in accounts) {
      if (a.role == role && a.loginId.toLowerCase() == key) return a;
    }
    return null;
  }

  StudentProfile? studentById(String id) {
    for (final s in students) {
      if (s.id == id) return s;
    }
    return null;
  }

  StudentProfile? findStudent(String name, String classCode) {
    final n = InputRules.clean(name, max: InputRules.maxName).toLowerCase();
    final c = classCode.trim().toUpperCase();
    for (final s in students) {
      if (s.classCode == c && s.name.toLowerCase() == n) return s;
    }
    return null;
  }

  List<StudentProfile> studentsIn(String classCode) =>
      students.where((s) => s.classCode == classCode).toList()..sort((a, b) => a.name.compareTo(b.name));

  Account? educatorFor(String classCode) {
    final c = classByCode(classCode);
    return c == null ? null : accountById(c.educatorId);
  }

  Future<StudentProfile> createStudent({required String name, required String classCode, required String pinHash}) async {
    final s = StudentProfile(
      id: _newId('STU'),
      name: InputRules.clean(name, max: InputRules.maxName),
      classCode: classCode.trim().toUpperCase(),
      pinHash: pinHash,
    );
    students.add(s);
    progress[s.id] = StudentProgress();
    _log(s.name, 'joined ${s.classCode}');
    await _save(['students', 'progress', 'activity']);
    return s;
  }

  Future<void> setStudentPin(String studentId, String pinHash) async {
    studentById(studentId)?.pinHash = pinHash;
    await _save(['students']);
  }

  /// The student chooses a new PIN on their next sign-in.
  Future<void> clearStudentPin(String studentId, {required String by}) async {
    final s = studentById(studentId);
    if (s == null) return;
    s.pinHash = null;
    _log(by, 'reset the PIN for ${s.name}');
    await _save(['students', 'activity']);
  }

  /// Q6 — a new class (at a school or a college) exists only when a teacher
  /// or faculty member registers it.
  Future<Account> registerEducator({
    required String name,
    required String email,
    required String secretHash,
    required String school,
    required String city,
    InstitutionKind kind = InstitutionKind.school,
  }) async {
    if (accountByLogin(Role.educator, email) != null) {
      throw const ActionRefused('An account with this email already exists. Sign in instead.');
    }
    final cleanSchool = InputRules.clean(school, max: InputRules.maxTitle);
    final initials = cleanSchool
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp('[A-Za-z]').hasMatch(w[0]) && w.length > 2)
        .map((w) => w[0].toUpperCase())
        .take(4)
        .join();
    final fallback = kind == InstitutionKind.college ? 'COL' : 'SCH';
    final base = 'AWA-${DateTime.now().year}-${initials.length >= 2 ? initials : fallback}';
    var code = base;
    var n = 2;
    while (classByCode(code) != null) {
      code = '$base${String.fromCharCode(64 + n)}';
      n++;
    }
    final account = Account(
      id: _newId('EDU'),
      role: Role.educator,
      name: InputRules.clean(name, max: InputRules.maxName),
      loginId: email.trim().toLowerCase(),
      secretHash: secretHash,
      school: cleanSchool,
      classCode: code,
      createdAt: DateTime.now(),
    );
    accounts.add(account);
    classes.add(ClassRoom(
      code: code,
      school: cleanSchool,
      educatorId: account.id,
      city: InputRules.clean(city, max: 40),
      kind: kind,
    ));
    _log(account.name, 'registered $cleanSchool ($code)');
    await _save(['accounts', 'classes', 'activity']);
    return account;
  }

  /// Q3 — moving a student keeps their ledger (keyed by student id),
  /// badges and progress intact.
  Future<void> transferStudent(String studentId, String newClassCode, {required String by}) async {
    final s = studentById(studentId);
    final target = classByCode(newClassCode);
    if (s == null || target == null) throw const ActionRefused('That person or group was not found.');
    final from = s.classCode;
    s.classCode = target.code;
    _log(by, 'moved ${s.name} from $from to ${target.code}');
    await _save(['students', 'activity']);
    await _sync.enqueue('student_transfer', {'studentId': s.id, 'from': from, 'to': target.code});
  }

  // ======================================================= login guard ====

  Duration? lockRemaining(String key) {
    final until = _guards[key]?.lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  /// After 5 failures the identifier locks for 30 s, doubling each time
  /// (capped at 15 min). Returns the new lock duration, if any.
  Future<Duration?> recordLoginFailure(String key, {required String actor}) async {
    final g = _guards.putIfAbsent(key, _LoginGuard.new);
    g.failures++;
    Duration? lock;
    if (g.failures >= 5) {
      final seconds = math.min(900, 30 * math.pow(2, g.failures - 5).toInt());
      lock = Duration(seconds: seconds);
      g.lockedUntil = DateTime.now().add(lock);
      _log(actor, 'was locked out after ${g.failures} failed sign-ins');
    }
    await _save(['loginGuards', 'activity']);
    return lock;
  }

  Future<void> recordLoginSuccess(String key) async {
    if (_guards.remove(key) != null) await _save(['loginGuards']);
  }

  int get activeLockouts => _guards.values.where((g) => g.lockedUntil?.isAfter(DateTime.now()) ?? false).length;

  void logEvent(String actor, String action) {
    _log(actor, action);
    unawaited(_save(['activity']));
  }

  // ============================================================= points ===

  Future<LedgerEntry> _sealEntry(String userId, int delta, String reason, String refKey, DateTime at) {
    final prev = ledger.isEmpty ? LedgerChain.genesis : ledger.last.hash;
    return LedgerChain.seal(
      key: _vault.macKey,
      prevHash: prev,
      userId: userId,
      delta: delta,
      reason: reason,
      refKey: refKey,
      at: at,
    );
  }

  int balanceOf(String userId) {
    var sum = 0;
    for (final e in ledger) {
      if (e.userId == userId) sum += e.delta;
    }
    return sum;
  }

  bool hasEarned(String userId, String refKey) =>
      ledger.any((e) => e.userId == userId && e.refKey == refKey);

  List<LedgerEntry> historyOf(String userId) =>
      ledger.where((e) => e.userId == userId).toList().reversed.toList();

  /// Adds points once per [refKey]. Returns the points actually awarded.
  Future<int> award(String userId, int points, String reason, String refKey) {
    return _exclusive(() async {
      if (points <= 0 || hasEarned(userId, refKey)) return 0;
      if (!ledgerIntact) {
        throw const ActionRefused('Points are paused: the ledger failed its integrity check. Ask a manager to review it.');
      }
      ledger.add(await _sealEntry(userId, points, reason, refKey, DateTime.now()));
      _touchDay(userId);
      await _save(['ledger', 'progress']);
      unawaited(_sync.enqueue('points', {'userId': userId, 'delta': points, 'reason': reason, 'ref': refKey}));
      return points;
    });
  }

  Future<void> _spend(String userId, int points, String reason, String refKey) async {
    if (!ledgerIntact) {
      throw const ActionRefused('Redemptions are paused until the ledger passes its integrity check.');
    }
    if (hasEarned(userId, refKey)) throw const ActionRefused('This reward was already redeemed.');
    if (balanceOf(userId) < points) throw const ActionRefused('They no longer have enough points.');
    ledger.add(await _sealEntry(userId, -points, reason, refKey, DateTime.now()));
  }

  Future<void> reverifyLedger() async {
    ledgerBrokenAt = await LedgerChain.firstBrokenIndex(ledger, _vault.macKey);
    notifyListeners();
  }

  // ============================================================ progress ===

  StudentProgress progressOf(String studentId) => progress.putIfAbsent(studentId, StudentProgress.new);

  void _touchDay(String userId) {
    if (studentById(userId) == null) return;
    progressOf(userId).activeDays.add(Fmt.dayKey(DateTime.now()));
  }

  Future<void> markActiveToday(String studentId) async {
    final days = progressOf(studentId).activeDays;
    if (days.add(Fmt.dayKey(DateTime.now()))) await _save(['progress']);
  }

  int streakOf(String studentId) {
    final days = progressOf(studentId).activeDays;
    var day = DateTime.now();
    if (!days.contains(Fmt.dayKey(day))) day = day.subtract(const Duration(days: 1));
    var streak = 0;
    while (days.contains(Fmt.dayKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<int> completeModule(String studentId, String moduleId) async {
    final p = progressOf(studentId);
    p.modulesDone.add(moduleId);
    final m = ContentSeed.module(moduleId);
    final pts = await award(studentId, PointRules.moduleCompleted, 'Finished "${m.title}"', 'module:$moduleId');
    await _save(['progress']);
    return pts;
  }

  /// Points only for improvement on your best score, so replaying a quiz
  /// can't farm points (the old app paid out on every attempt).
  Future<({int points, bool newBest, int previousBest})> recordQuiz(
    String studentId,
    String moduleId,
    int correct,
    int total,
  ) async {
    final p = progressOf(studentId);
    final prev = p.quizBest[moduleId] ?? 0;
    var pts = 0;
    if (correct > prev) {
      p.quizBest[moduleId] = correct;
      final m = ContentSeed.module(moduleId);
      pts = await award(studentId, (correct - prev) * PointRules.perCorrectAnswer,
          'Quiz: ${m.title} ($correct/$total)', 'quiz:$moduleId:$correct');
    }
    await _save(['progress']);
    await _sync.enqueue('quiz_score', {
      'studentId': studentId,
      'moduleId': moduleId,
      'correct': correct,
      'total': total,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    return (points: pts, newBest: correct > prev, previousBest: prev);
  }

  Future<int> completeSortGame(String studentId) =>
      award(studentId, PointRules.sortGame, 'Sorting challenge completed', 'sort_game');

  /// Q12 — daily bonus when the school or college stays under its water target.
  Future<int> claimWaterBonus(String studentId) => award(studentId, PointRules.waterTargetBonus,
      'Stayed under the water target', 'water:${Fmt.dayKey(DateTime.now())}');

  StudentSummary summaryOf(StudentProfile s) {
    final p = progressOf(s.id);
    final samples = <int>[];
    for (final e in p.quizBest.entries) {
      final total = ContentSeed.quizFor(e.key).length;
      samples.add((e.value / total * 100).round());
    }
    final avg = samples.isEmpty ? s.importedScorePct : (samples.reduce((a, b) => a + b) / samples.length).round();
    DateTime? last;
    for (final e in ledger) {
      if (e.userId == s.id && (last == null || e.at.isAfter(last))) last = e.at;
    }
    return StudentSummary(
      profile: s,
      points: balanceOf(s.id),
      modulesDone: p.modulesDone.length,
      avgScorePct: avg,
      lastActive: last,
    );
  }

  /// Average best quiz score (%) per module across a class, or null if no one has tried it.
  Map<String, int?> moduleAverages(String classCode) {
    final out = <String, int?>{};
    final roster = studentsIn(classCode);
    for (final m in ContentSeed.modules) {
      final total = ContentSeed.quizFor(m.id).length;
      final scores = [
        for (final s in roster)
          if (progressOf(s.id).quizBest[m.id] != null) progressOf(s.id).quizBest[m.id]! / total * 100,
      ];
      out[m.id] = scores.isEmpty ? null : (scores.reduce((a, b) => a + b) / scores.length).round();
    }
    return out;
  }

  /// Points-earning actions per day for the last 7 days (oldest first).
  List<int> weeklyEngagement(String? classCode) {
    final ids = classCode == null ? null : studentsIn(classCode).map((s) => s.id).toSet();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6));
    final counts = List<int>.filled(7, 0);
    for (final e in ledger) {
      if (e.delta <= 0) continue;
      if (ids != null && !ids.contains(e.userId)) continue;
      final d = DateTime(e.at.year, e.at.month, e.at.day).difference(start).inDays;
      if (d >= 0 && d < 7) counts[d]++;
    }
    return counts;
  }

  // ======================================================= announcements ===

  static bool isQuietHours(DateTime t) =>
      t.weekday <= DateTime.friday && t.hour >= 8 && t.hour < 15;

  Future<Announcement> postAnnouncement({
    required SessionUser sender,
    required String message,
    required String audience,
    bool urgent = false,
  }) async {
    final text = InputRules.clean(message);
    if (text.isEmpty) throw const ActionRefused('Write a message first.');
    final size = audience == 'ALL' ? students.length : students.where((s) => s.classCode == audience).length;
    final a = Announcement(
      id: _newId('ANN'),
      message: text,
      senderId: sender.id,
      senderName: sender.name,
      senderRole: sender.role,
      sentAt: DateTime.now(),
      audience: audience,
      audienceSize: size,
      urgent: urgent,
    );
    announcements.insert(0, a);
    _log(sender.name, audience == 'ALL' ? 'sent a broadcast to everyone' : 'posted an announcement to $audience');
    await _save(['announcements', 'activity']);
    await _sync.enqueue('announcement', {
      'id': a.id,
      'message': a.message,
      'audience': audience,
      'urgent': urgent,
      'sentAt': a.sentAt.toUtc().toIso8601String(),
    });
    return a;
  }

  List<Announcement> announcementsFor(String? classCode) =>
      announcements.where((a) => a.reaches(classCode)).toList()..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  List<Announcement> openTasksFor(SessionUser student) => announcementsFor(student.classCode)
      .where((a) => !a.completedBy.contains(student.id))
      .toList();

  List<Announcement> sentBy(String senderId) => announcements.where((a) => a.senderId == senderId).toList();

  Future<int> completeAnnouncement(String announcementId, String studentId) async {
    final a = announcements.firstWhere((x) => x.id == announcementId,
        orElse: () => throw const ActionRefused('That notice no longer exists.'));
    a.completedBy.add(studentId);
    await _save(['announcements']);
    // Queued before the points so the server sees the completion first.
    await _sync.enqueue('announcement_done', {'announcementId': a.id});
    final from = a.senderRole == Role.ngo ? 'NGO task' : '${kindOf(studentById(studentId)?.classCode).groupTitle} task';
    return award(studentId, a.points, '$from from ${a.senderName}', 'ann:${a.id}');
  }

  /// Q2 relay — applies announcements and completions fetched from the
  /// server, so a task posted on an educator's phone appears on every
  /// student's phone in that class, and the educator sees who finished it.
  /// Everything is cleaned again here: the server is trusted, its data isn't.
  void mergeRemote(List<RemoteEvent> events) {
    var changed = false;
    for (final e in events) {
      final d = e.data;
      if (e.type == 'announcement') {
        final id = d['id'];
        final message = d['message'];
        final audience = d['audience'];
        final role = Role.values.asNameMap()[d['senderRole']];
        if (id is! String || message is! String || audience is! String || role == null) continue;
        if (role != Role.educator && role != Role.ngo) continue;
        if (announcements.any((a) => a.id == id)) continue;
        final sentAt = d['sentAt'];
        final senderId = d['senderId'];
        final senderName = d['senderName'];
        announcements.add(Announcement(
          id: id,
          message: InputRules.clean(message),
          senderId: senderId is String ? senderId : 'server',
          senderName: InputRules.clean(senderName is String ? senderName : 'AquaAware', max: InputRules.maxName),
          senderRole: role,
          sentAt: (sentAt is String ? DateTime.tryParse(sentAt)?.toLocal() : null) ?? DateTime.now(),
          audience: audience,
          audienceSize: audience == 'ALL' ? students.length : students.where((s) => s.classCode == audience).length,
          urgent: d['urgent'] == true,
        ));
        changed = true;
      } else if (e.type == 'announcement_done') {
        final id = d['announcementId'];
        final studentId = d['studentId'];
        if (id is! String || studentId is! String) continue;
        for (final a in announcements) {
          if (a.id == id && a.completedBy.add(studentId)) changed = true;
        }
      }
    }
    if (!changed) return;
    announcements.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    unawaited(_save(['announcements']));
  }

  // ============================================================ messages ===

  Future<DirectMessage> sendMessage({
    required SessionUser from,
    required String toId,
    required String toName,
    required String body,
  }) async {
    final text = InputRules.clean(body);
    if (text.isEmpty) throw const ActionRefused('Write a message first.');
    final m = DirectMessage(
      id: _newId('MSG'),
      fromId: from.id,
      fromName: from.name,
      fromRole: from.role,
      toId: toId,
      toName: toName,
      body: text,
      sentAt: DateTime.now(),
    );
    messages.add(m);
    await _save(['messages']);
    return m;
  }

  List<DirectMessage> thread(String a, String b) => messages
      .where((m) => (m.fromId == a && m.toId == b) || (m.fromId == b && m.toId == a))
      .toList()
    ..sort((x, y) => x.sentAt.compareTo(y.sentAt));

  /// Latest message per conversation partner, newest first.
  List<DirectMessage> conversationsOf(String userId) {
    final latest = <String, DirectMessage>{};
    for (final m in messages) {
      if (m.fromId != userId && m.toId != userId) continue;
      final peer = m.fromId == userId ? m.toId : m.fromId;
      final cur = latest[peer];
      if (cur == null || m.sentAt.isAfter(cur.sentAt)) latest[peer] = m;
    }
    return latest.values.toList()..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  }

  int unreadFor(String userId, {String? fromId}) =>
      messages.where((m) => m.toId == userId && !m.read && (fromId == null || m.fromId == fromId)).length;

  Future<void> markThreadRead(String userId, String peerId) async {
    var changed = false;
    for (final m in messages) {
      if (m.toId == userId && m.fromId == peerId && !m.read) {
        m.read = true;
        changed = true;
      }
    }
    if (changed) await _save(['messages']);
  }

  // =========================================================== resources ===

  List<Resource> resourcesFor(String classCode) =>
      resources.where((r) => r.classCode == classCode).toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  int unseenResources(String classCode, String userId) =>
      resources.where((r) => r.classCode == classCode && !r.seenBy.contains(userId)).length;

  Future<void> markResourcesSeen(String classCode, String userId) async {
    var changed = false;
    for (final r in resources) {
      if (r.classCode == classCode && r.seenBy.add(userId)) changed = true;
    }
    if (changed) await _save(['resources']);
  }

  Future<Resource> addResource({
    required SessionUser by,
    required String classCode,
    required String fileName,
    int? sizeBytes,
    String? localPath,
  }) async {
    final name = InputRules.clean(fileName, max: InputRules.maxTitle);
    final r = Resource(
      id: _newId('RES'),
      name: name,
      kind: Resource.kindFor(name),
      classCode: classCode,
      uploaderName: by.name,
      addedAt: DateTime.now(),
      sizeBytes: sizeBytes,
      localPath: localPath,
      seenBy: {by.id},
    );
    resources.insert(0, r);
    _log(by.name, 'shared "$name"');
    await _save(['resources', 'activity']);
    return r;
  }

  Future<Resource?> removeResource(String id) async {
    final idx = resources.indexWhere((r) => r.id == id);
    if (idx < 0) return null;
    final r = resources.removeAt(idx);
    await _save(['resources']);
    return r;
  }

  // ============================================================= pickups ===

  PickupRequest? activePickupFor(String studentId) {
    for (final p in pickups.reversed) {
      if (p.studentId == studentId && p.status == PickupStatus.onTheWay) return p;
    }
    return null;
  }

  PickupRequest? pickupById(String id) {
    for (final p in pickups) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool collectorBusy(Collector c) =>
      !c.available || pickups.any((p) => p.collectorId == c.id && p.status == PickupStatus.onTheWay);

  /// Q4 — smart paging: only the three nearest free collectors are alerted.
  List<(Collector, double)> nearestFree(GeoPoint from, {int count = 3, String? wasteType}) {
    final list = [
      for (final c in CommunitySeed.collectors)
        if (!collectorBusy(c) && (wasteType == null || c.wasteType == wasteType))
          (c, Geo.distanceMeters(from, c.location)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return list.take(count).toList();
  }

  Future<PickupRequest> requestPickup({
    required SessionUser student,
    required Collector collector,
    required GeoPoint from,
  }) async {
    if (activePickupFor(student.id) != null) {
      throw const ActionRefused('You already have a pickup on the way. Finish or cancel it first.');
    }
    if (collectorBusy(collector)) throw ActionRefused('${collector.name} is busy right now. Pick another collector.');
    final meters = Geo.distanceMeters(from, collector.location);
    final p = PickupRequest(
      id: _newId('PCK'),
      studentId: student.id,
      collectorId: collector.id,
      requestedAt: DateTime.now(),
      etaMinutes: Geo.etaMinutes(meters),
      distanceMeters: meters,
    );
    pickups.add(p);
    _log(student.name, 'requested a ${collector.wasteType.toLowerCase()} pickup from ${collector.name}');
    await _save(['pickups', 'activity']);
    await _sync.enqueue('pickup', {'id': p.id, 'collectorId': collector.id});
    return p;
  }

  /// True once enough time has passed for the collector to have arrived.
  bool canConfirmPickup(PickupRequest p, [DateTime? now]) =>
      (now ?? DateTime.now()).difference(p.requestedAt) >= PointRules.minPickupWait;

  Future<int> completePickup(String pickupId) async {
    final p = pickupById(pickupId);
    if (p == null || p.status != PickupStatus.onTheWay) return 0;
    final c = CommunitySeed.collector(p.collectorId);
    // Handovers are self-reported, so the old request → "handed over" →
    // request loop could farm unlimited points. Require a realistic wait and
    // cap how many handovers per day earn points.
    if (!canConfirmPickup(p)) {
      throw ActionRefused('${c.name} is still on the way. Confirm once you have handed over your waste.');
    }
    final now = DateTime.now();
    p.status = PickupStatus.handedOver;
    p.closedAt = now;
    await _save(['pickups']);
    final today = Fmt.dayKey(now);
    final handedToday = pickups
        .where((x) =>
            x.studentId == p.studentId &&
            x.status == PickupStatus.handedOver &&
            x.closedAt != null &&
            Fmt.dayKey(x.closedAt!) == today)
        .length; // includes this one
    if (handedToday > PointRules.maxRewardedPickupsPerDay) {
      _log(studentById(p.studentId)?.name ?? p.studentId, 'reached the daily pickup-points limit');
      await _save(['activity']);
      return 0;
    }
    return award(p.studentId, PointRules.pickupHandedOver, 'Handed ${c.wasteType.toLowerCase()} waste to ${c.name}',
        'pickup:${p.id}');
  }

  Future<void> cancelPickup(String pickupId) async {
    final p = pickupById(pickupId);
    if (p == null || p.status != PickupStatus.onTheWay) return;
    p.status = PickupStatus.cancelled;
    p.closedAt = DateTime.now();
    await _save(['pickups']);
  }

  int handedOverCount(String? classCode) {
    final ids = classCode == null ? null : studentsIn(classCode).map((s) => s.id).toSet();
    return pickups.where((p) => p.status == PickupStatus.handedOver && (ids == null || ids.contains(p.studentId))).length;
  }

  // ============================================================== claims ===

  List<RewardClaim> claimsOf(String studentId) =>
      claims.where((c) => c.studentId == studentId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  RewardClaim? claimById(String id) {
    for (final c in claims) {
      if (c.id == id) return c;
    }
    return null;
  }

  int reservedPoints(String studentId) =>
      claims.where((c) => c.studentId == studentId && c.isOpen).fold(0, (sum, c) => sum + c.points);

  int availablePoints(String studentId) => balanceOf(studentId) - reservedPoints(studentId);

  /// Q8 + Q9 — creates a signed, single-use, expiring claim ticket.
  Future<RewardClaim> createClaim({required SessionUser student, required Reward reward}) async {
    if (!ledgerIntact) {
      throw const ActionRefused('Claims are paused until the points ledger passes its integrity check.');
    }
    if (availablePoints(student.id) < reward.points) {
      throw ActionRefused('You need ${reward.points - availablePoints(student.id)} more points for ${reward.name}.');
    }
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final recent = claims.where((c) => c.studentId == student.id && c.createdAt.isAfter(since)).length;
    if (recent >= PointRules.maxClaimsPerDay) {
      _log(student.name, 'was stopped by the claim limit (fraud guard)');
      await _save(['activity']);
      throw const ActionRefused('You have reached today\'s limit of 3 claims. Try again tomorrow.');
    }
    final id = _newId('CLM');
    final token = await signer.sign(
      TokenKind.claim,
      {'cid': id, 'sub': student.id, 'rid': reward.id, 'pts': reward.points},
      ttl: const Duration(days: 7),
    );
    final check = await signer.verify(token, expect: TokenKind.claim);
    final claim = RewardClaim(
      id: id,
      studentId: student.id,
      studentName: student.name,
      rewardId: reward.id,
      rewardName: reward.name,
      points: reward.points,
      token: token,
      nonce: check.token!.nonce,
      createdAt: DateTime.now(),
      expiresAt: check.token!.expiresAt,
    );
    claims.add(claim);
    _log(student.name, 'created a claim for ${reward.name}');
    await _save(['claims', 'activity']);
    return claim;
  }

  Future<void> cancelClaim(String claimId) async {
    final c = claimById(claimId);
    if (c == null || c.status != ClaimStatus.pending) return;
    c.status = ClaimStatus.cancelled;
    await _save(['claims']);
  }

  Future<void> markClaimLocation(String claimId) async {
    final c = claimById(claimId);
    if (c == null) return;
    c.locationVerified = true;
    await _save(['claims']);
  }

  /// NGO desk redeems a claim: signature, expiry, kind, single-use nonce,
  /// matching claim record and sufficient balance are all checked.
  Future<RedeemResult> redeemClaim(String raw, {required SessionUser desk}) {
    return _exclusive(() async {
      final check = await signer.verify(raw, expect: TokenKind.claim);
      if (!check.isValid) throw ActionRefused(check.error!);
      final t = check.token!;
      if (usedNonces.contains(t.nonce)) {
        _log(desk.name, 'blocked a replayed reward code');
        await _save(['activity']);
        throw const ActionRefused('This code was already used. Each claim code works once.');
      }
      final claim = claimById(t.str('cid') ?? '');
      if (claim == null || claim.nonce != t.nonce) {
        throw const ActionRefused('No matching claim was found for this code.');
      }
      if (claim.status == ClaimStatus.cancelled) throw const ActionRefused('They cancelled this claim.');
      if (claim.status == ClaimStatus.redeemed) throw const ActionRefused('This claim was already redeemed.');
      if (t.str('sub') != claim.studentId || t.integer('pts') != claim.points) {
        throw const ActionRefused('The code does not match the claim on record.');
      }
      await _spend(claim.studentId, claim.points, 'Redeemed: ${claim.rewardName}', 'claim:${claim.id}');
      claim.status = ClaimStatus.redeemed;
      claim.redeemedAt = DateTime.now();
      claim.redeemedBy = desk.name;
      usedNonces.add(t.nonce);
      _log(desk.name, 'handed ${claim.rewardName} to ${claim.studentName}');
      await _save(['claims', 'ledger', 'nonces', 'activity']);
      unawaited(_sync.enqueue('redemption', {'claimId': claim.id, 'nonce': t.nonce, 'desk': desk.id}));
      return RedeemResult(claim: claim, studentName: claim.studentName);
    });
  }

  // ============================================================ check-ins ==

  /// NGO desk shows this at an event; it rotates every 15 minutes.
  Future<String> issueCheckinCode({required SessionUser desk, required NgoActivity activity}) => signer.sign(
        TokenKind.checkin,
        {'ngo': desk.ngoId, 'act': activity.id, 'name': activity.name},
        ttl: const Duration(minutes: 15),
      );

  /// Students scan the event code. Many students share one code, so the
  /// single-use rule is per student per activity (via the ledger refKey).
  Future<({int points, String activityName})> checkIn(String raw, {required SessionUser student}) async {
    final check = await signer.verify(raw, expect: TokenKind.checkin);
    if (!check.isValid) throw ActionRefused(check.error!);
    final t = check.token!;
    final ngoId = t.str('ngo') ?? '';
    final act = t.str('act') ?? '';
    final name = t.str('name') ?? 'NGO activity';
    final ref = 'checkin:$ngoId:$act';
    if (hasEarned(student.id, ref)) throw const ActionRefused('You have already checked in to this activity.');
    final pts = await award(student.id, PointRules.activityCheckIn, 'Checked in: $name', ref);
    _log(student.name, 'checked in to $name');
    await _save(['activity']);
    return (points: pts, activityName: name);
  }

  // ================================================================ NGOs ===

  /// Seeded and app-scheduled events for one NGO, soonest first.
  List<NgoActivity> activitiesFor(String ngoId) {
    final seeded = CommunitySeed.ngos.where((n) => n.id == ngoId).expand((n) => n.activities);
    final mine = customActivities.where((a) => a.ngoId == ngoId);
    return [...seeded, ...mine]..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Students who checked in to an activity through the app (from the ledger,
  /// so the number cannot be inflated by editing a counter).
  int checkInsFor(String ngoId, String activityId) {
    final ref = 'checkin:$ngoId:$activityId';
    return ledger.where((e) => e.refKey == ref && e.delta > 0).length;
  }

  /// Replaces the old "+ Add New Activity" button, which did nothing.
  Future<NgoActivity> addActivity({
    required SessionUser desk,
    required String name,
    required DateTime date,
    String? place,
  }) async {
    final ngoId = desk.ngoId;
    if (desk.role != Role.ngo || ngoId == null) {
      throw const ActionRefused('Only NGO desks can schedule activities.');
    }
    final cleanName = InputRules.clean(name, max: InputRules.maxTitle);
    if (cleanName.length < 3) throw const ActionRefused('Give the activity a name of at least 3 letters.');
    final today = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(DateTime(today.year, today.month, today.day))) {
      throw const ActionRefused('Pick today or a later date.');
    }
    final cleanPlace = place == null ? '' : InputRules.clean(place, max: InputRules.maxTitle);
    final a = NgoActivity(
      id: _newId('ACT'),
      name: cleanName,
      date: day,
      participants: 0,
      place: cleanPlace.isEmpty ? null : cleanPlace,
      ngoId: ngoId,
    );
    customActivities.add(a);
    _log(desk.name, 'scheduled "$cleanName" for ${Fmt.shortDate(day)}');
    await _save(['ngoActivities', 'activity']);
    unawaited(_sync.enqueue('activity', {'id': a.id, 'ngoId': ngoId, 'date': Fmt.dayKey(day)}));
    return a;
  }

  /// Desks can only cancel events they scheduled themselves.
  Future<void> removeActivity(String activityId, {required SessionUser desk}) async {
    final idx = customActivities.indexWhere((a) => a.id == activityId && a.ngoId == desk.ngoId);
    if (idx < 0) return;
    final a = customActivities.removeAt(idx);
    _log(desk.name, 'cancelled "${a.name}"');
    await _save(['ngoActivities', 'activity']);
  }

  /// Rewards this desk has handed over, newest first.
  List<RewardClaim> redemptionsBy(String deskName) => claims
      .where((c) => c.status == ClaimStatus.redeemed && c.redeemedBy == deskName)
      .toList()
    ..sort((a, b) => (b.redeemedAt ?? b.createdAt).compareTo(a.redeemedAt ?? a.createdAt));

  /// Students who completed at least one of this sender's announcements.
  int studentsReachedBy(String senderId) =>
      sentBy(senderId).expand((a) => a.completedBy).toSet().length;

  // ============================================================= manager ===

  List<Account> get educatorAccounts =>
      accounts.where((a) => a.role == Role.educator).toList()..sort((a, b) => a.name.compareTo(b.name));

  int get joinedStudents => students.where((s) => s.isClaimed).length;

  int get openClaims => claims.where((c) => c.isOpen).length;

  /// Points issued (positive entries) and redeemed (negative) across everyone.
  ({int issued, int redeemed}) pointTotals() {
    var issued = 0;
    var redeemed = 0;
    for (final e in ledger) {
      if (e.delta > 0) {
        issued += e.delta;
      } else {
        redeemed -= e.delta;
      }
    }
    return (issued: issued, redeemed: redeemed);
  }
}
