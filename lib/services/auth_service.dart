import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/net/sync_service.dart';
import '../core/platform/biometric_service.dart';
import '../core/security/crypto_service.dart';
import '../core/security/input_rules.dart';
import '../core/security/secure_vault.dart';
import '../data/app_store.dart';
import '../data/models/models.dart';

class AuthResult {
  const AuthResult._({this.ok = false, this.message, this.lockedFor, this.newProfile = false, this.classCode});
  const AuthResult.success({bool newProfile = false, String? classCode})
      : this._(ok: true, newProfile: newProfile, classCode: classCode);
  const AuthResult.failure(String message, {Duration? lockedFor})
      : this._(message: message, lockedFor: lockedFor);

  final bool ok;
  final String? message;
  final Duration? lockedFor;
  final bool newProfile;
  final String? classCode;
}

class QuickUnlockInfo {
  const QuickUnlockInfo({required this.userId, required this.role, required this.name});
  final String userId;
  final Role role;
  final String name;
}

/// Authentication, sessions and lockout.
///
/// * Secrets are verified against PBKDF2 hashes; a dummy hash is checked when
///   an account does not exist so response time doesn't reveal valid emails.
/// * Error messages never say *which* part was wrong.
/// * 5 failures lock the identifier with exponential back-off.
/// * Sessions last 8 hours, are HMAC-signed in the platform keystore, and end
///   after 15 minutes of inactivity.
/// * Biometric quick unlock is offered to staff roles only — students often
///   share classroom devices.
class AuthService extends ChangeNotifier {
  AuthService(this._vault, this._store, [this._sync]) {
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  final SecureVault _vault;
  final AppStore _store;

  /// When a server is configured, signing in here also signs in there.
  final SyncService? _sync;

  static const sessionLength = Duration(hours: 8);
  static const idleLimit = Duration(minutes: 15);
  static const _sessionKey = 'aq.session.v1';
  static const _quickKey = 'aq.quick.v1';
  // Hash of a random value nobody knows — used to equalise timing.
  static const _dummyHash =
      r'pbkdf2-sha256$100000$AAAAAAAAAAAAAAAAAAAAAA==$47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=';

  SessionUser? _user;
  DateTime? _expiresAt;
  Timer? _idleTimer;
  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);

  /// Shown on the login screen after an automatic sign-out.
  String? signedOutReason;

  SessionUser? get user => _user;
  bool get isSignedIn => _user != null;
  DateTime? get expiresAt => _expiresAt;

  // ------------------------------------------------------------ session ---

  Future<void> restore() async {
    final raw = await _vault.readSecret(_sessionKey);
    if (raw == null) return;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      final uid = j['uid']! as String;
      final role = Role.values.byName(j['role']! as String);
      final exp = DateTime.fromMillisecondsSinceEpoch(j['exp']! as int);
      final sig = j['sig']! as String;
      if (!await _validSig('$uid|${role.name}|${exp.millisecondsSinceEpoch}', sig)) {
        throw const FormatException('bad signature');
      }
      if (DateTime.now().isAfter(exp)) {
        signedOutReason = 'Your session ended. Please sign in again.';
        throw const FormatException('expired');
      }
      final u = _resolve(uid, role);
      if (u == null) throw const FormatException('unknown user');
      _user = u;
      _expiresAt = exp;
      _armIdle();
      _sync?.bindUser(u.id);
    } catch (_) {
      await _vault.deleteSecret(_sessionKey);
      _user = null;
    }
  }

  SessionUser? _resolve(String uid, Role role) {
    if (role == Role.student) {
      final s = _store.studentById(uid);
      if (s == null) return null;
      final c = _store.classByCode(s.classCode);
      return SessionUser(id: s.id, role: Role.student, name: s.name, classCode: s.classCode, school: c?.school);
    }
    final a = _store.accountById(uid);
    if (a == null || a.role != role) return null;
    return a.toSession();
  }

  /// Re-reads the signed-in student's class (e.g. after a transfer).
  void refreshUser() {
    final u = _user;
    if (u == null) return;
    final fresh = _resolve(u.id, u.role);
    if (fresh != null) {
      _user = fresh;
      notifyListeners();
    }
  }

  Future<String> _sign(String data) async =>
      Crypto.hex(await Crypto.hmacSha256(_vault.macKey, utf8.encode(data)));

  Future<bool> _validSig(String data, String sig) async =>
      Crypto.constantTimeEquals(utf8.encode(await _sign(data)), utf8.encode(sig));

  Future<void> _startSession(SessionUser u) async {
    final exp = DateTime.now().add(sessionLength);
    final payload = '${u.id}|${u.role.name}|${exp.millisecondsSinceEpoch}';
    await _vault.writeSecret(
      _sessionKey,
      jsonEncode({'uid': u.id, 'role': u.role.name, 'exp': exp.millisecondsSinceEpoch, 'sig': await _sign(payload)}),
    );
    _user = u;
    _expiresAt = exp;
    signedOutReason = null;
    _sync?.bindUser(u.id);
    _store.logEvent(u.name, 'signed in');
    if (u.role == Role.student) await _store.markActiveToday(u.id);
    _armIdle();
    notifyListeners();
  }

  Future<void> signOut({String? reason}) async {
    _idleTimer?.cancel();
    _user = null;
    _expiresAt = null;
    signedOutReason = reason;
    await _vault.deleteSecret(_sessionKey);
    final sync = _sync;
    if (sync != null) unawaited(sync.signOut());
    notifyListeners();
  }

  /// Called on any pointer or key activity.
  void touch() {
    if (_user == null) return;
    final now = DateTime.now();
    if (_expiresAt != null && now.isAfter(_expiresAt!)) {
      unawaited(signOut(reason: 'Your 8-hour session ended. Please sign in again.'));
      return;
    }
    if (now.difference(_lastTouch) < const Duration(seconds: 5)) return;
    _lastTouch = now;
    _armIdle();
  }

  bool _onKey(KeyEvent event) {
    touch();
    return false; // never consume the key
  }

  void _armIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleLimit, () {
      unawaited(signOut(reason: 'You were signed out after 15 minutes without activity.'));
    });
  }

  // ------------------------------------------------------------- sign in ---

  Future<AuthResult> signInWithSecret({
    required Role role,
    required String loginId,
    required String secret,
  }) async {
    assert(role != Role.student);
    final id = loginId.trim().toLowerCase();
    final key = '${role.name}:$id';
    final locked = _store.lockRemaining(key);
    if (locked != null) {
      return AuthResult.failure('Too many attempts. Try again in ${_fmt(locked)}.', lockedFor: locked);
    }
    final account = _store.accountByLogin(role, id);
    final ok = await PasswordHasher.verify(secret, account?.secretHash ?? _dummyHash);
    if (account == null || !ok) {
      final lock = await _store.recordLoginFailure(key, actor: role == Role.ngo ? 'NGO desk $id' : id);
      return AuthResult.failure(
        lock != null
            ? 'Too many attempts. Try again in ${_fmt(lock)}.'
            : role == Role.ngo
                ? 'That organisation and access code do not match.'
                : 'That email and password do not match.',
        lockedFor: lock,
      );
    }
    await _store.recordLoginSuccess(key);
    await _startSession(account.toSession());
    final sync = _sync;
    if (sync != null) {
      unawaited(sync.signInToServer(
        localUserId: account.id,
        path: '/auth/staff',
        body: {'role': role.name, 'loginId': id, 'secret': secret},
      ));
    }
    return const AuthResult.success();
  }

  /// Students join with name + class code + a 4-digit PIN. The first sign-in
  /// claims a profile and sets the PIN; afterwards the PIN is required.
  Future<AuthResult> signInStudent({
    required String name,
    required String classCode,
    required String pin,
  }) async {
    final cleanName = InputRules.clean(name, max: InputRules.maxName);
    final code = classCode.trim().toUpperCase();
    final room = _store.classByCode(code);
    if (room == null) {
      return const AuthResult.failure('We could not find that class code. Check it with your educator.');
    }
    final key = 'student:$code:${cleanName.toLowerCase()}';
    final locked = _store.lockRemaining(key);
    if (locked != null) {
      return AuthResult.failure('Too many attempts. Try again in ${_fmt(locked)}.', lockedFor: locked);
    }

    var student = _store.findStudent(cleanName, code);
    var isNew = false;
    if (student != null && student.isClaimed) {
      if (!await PasswordHasher.verify(pin, student.pinHash!)) {
        final lock = await _store.recordLoginFailure(key, actor: cleanName);
        return AuthResult.failure(
          lock != null ? 'Too many attempts. Try again in ${_fmt(lock)}.' : 'That PIN is not right. Ask your educator if you forgot it.',
          lockedFor: lock,
        );
      }
    } else {
      final pinError = InputRules.validatePin(pin, isNew: true);
      if (pinError != null) return AuthResult.failure(pinError);
      final hash = await PasswordHasher.hash(pin);
      if (student == null) {
        student = await _store.createStudent(name: cleanName, classCode: code, pinHash: hash);
      } else {
        await _store.setStudentPin(student.id, hash);
      }
      isNew = true;
    }
    await _store.recordLoginSuccess(key);
    await _startSession(SessionUser(
      id: student.id,
      role: Role.student,
      name: student.name,
      classCode: student.classCode,
      school: room.school,
    ));
    final sync = _sync;
    if (sync != null) {
      unawaited(sync.signInToServer(
        localUserId: student.id,
        path: '/auth/student',
        body: {'name': cleanName, 'classCode': code, 'pin': pin},
      ));
    }
    return AuthResult.success(newProfile: isNew);
  }

  Future<AuthResult> registerEducator({
    required String name,
    required String email,
    required String password,
    required String school,
    required String city,
  }) async {
    final hash = await PasswordHasher.hash(password);
    try {
      final account = await _store.registerEducator(
        name: name,
        email: email,
        secretHash: hash,
        school: school,
        city: city,
      );
      return AuthResult.success(classCode: account.classCode);
    } on ActionRefused catch (e) {
      return AuthResult.failure(e.message);
    }
  }

  /// Educators can reset a student's PIN (the student sets a new one next time).
  Future<void> resetStudentPin(String studentId, {required String by}) =>
      _store.clearStudentPin(studentId, by: by);

  // ------------------------------------------------------- quick unlock ---

  bool get canOfferQuickUnlock => _user != null && _user!.role != Role.student;

  Future<bool> enableQuickUnlock() async {
    final u = _user;
    if (u == null || u.role == Role.student) return false;
    if (!await BiometricService.isAvailable()) return false;
    if (!await BiometricService.confirm('Confirm it is you to enable quick unlock')) return false;
    final data = '${u.id}|${u.role.name}|${u.name}';
    await _vault.writeSecret(
      _quickKey,
      jsonEncode({'uid': u.id, 'role': u.role.name, 'name': u.name, 'sig': await _sign(data)}),
    );
    notifyListeners();
    return true;
  }

  Future<QuickUnlockInfo?> quickUnlockInfo() async {
    final raw = await _vault.readSecret(_quickKey);
    if (raw == null) return null;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      final info = QuickUnlockInfo(
        userId: j['uid']! as String,
        role: Role.values.byName(j['role']! as String),
        name: j['name']! as String,
      );
      if (!await _validSig('${info.userId}|${info.role.name}|${info.name}', j['sig']! as String)) return null;
      return info;
    } catch (_) {
      return null;
    }
  }

  Future<AuthResult> quickUnlock() async {
    final info = await quickUnlockInfo();
    if (info == null) return const AuthResult.failure('Quick unlock is not set up on this device.');
    if (!await BiometricService.confirm('Unlock AquaAware as ${info.name}')) {
      return const AuthResult.failure('Unlock was cancelled or not recognised.');
    }
    final u = _resolve(info.userId, info.role);
    if (u == null) {
      await forgetQuickUnlock();
      return const AuthResult.failure('That account no longer exists on this device.');
    }
    await _startSession(u);
    return const AuthResult.success();
  }

  Future<void> forgetQuickUnlock() async {
    await _vault.deleteSecret(_quickKey);
    notifyListeners();
  }

  static String _fmt(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes} min ${d.inSeconds % 60} s';
    return '${d.inSeconds.clamp(1, 59)} s';
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _idleTimer?.cancel();
    super.dispose();
  }
}
