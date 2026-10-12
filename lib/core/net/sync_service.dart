import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../security/crypto_service.dart';
import '../security/secure_vault.dart';

enum OutboxStatus { pending, sent, rejected }

class OutboxItem {
  OutboxItem({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.ownerId,
    this.attempts = 0,
    this.status = OutboxStatus.pending,
    this.lastError,
  });

  final String id;
  final String kind;
  final Map<String, Object?> payload;
  final DateTime createdAt;

  /// The local user who created the item. Items are only ever sent with that
  /// person's own server session, so one student's quiz can never be sent in
  /// another student's name on a shared classroom device.
  final String? ownerId;
  int attempts;
  OutboxStatus status;
  String? lastError;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind,
        'payload': payload,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'ownerId': ownerId,
        'attempts': attempts,
        'status': status.name,
        'lastError': lastError,
      };

  factory OutboxItem.fromJson(Map<String, Object?> j) => OutboxItem(
        id: j['id']! as String,
        kind: j['kind']! as String,
        payload: (j['payload']! as Map).cast<String, Object?>(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt']! as int),
        ownerId: j['ownerId'] as String?,
        attempts: (j['attempts'] as int?) ?? 0,
        status: OutboxStatus.values.byName((j['status'] as String?) ?? 'pending'),
        lastError: j['lastError'] as String?,
      );
}

/// Something that happened on another device, fetched from the server.
class RemoteEvent {
  const RemoteEvent({required this.seq, required this.type, required this.data});
  final int seq;
  final String type;
  final Map<String, Object?> data;
}

/// A server session: a short-lived JWT plus a per-session HMAC key that the
/// server issued at sign-in. Kept only in the platform keystore.
class _ApiSession {
  const _ApiSession({required this.token, required this.key, required this.expiresAt, required this.localUserId});

  final String token;
  final List<int> key;
  final DateTime expiresAt;
  final String localUserId;

  bool get valid => DateTime.now().isBefore(expiresAt);

  String encode() => jsonEncode({
        't': token,
        'k': base64.encode(key),
        'e': expiresAt.millisecondsSinceEpoch,
        'u': localUserId,
      });

  static _ApiSession? decode(String? raw) {
    if (raw == null) return null;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      return _ApiSession(
        token: j['t']! as String,
        key: base64.decode(j['k']! as String),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(j['e']! as int),
        localUserId: j['u']! as String,
      );
    } catch (_) {
      return null;
    }
  }
}

enum _Send { ok, rejected, retryLater, sessionEnded }

/// Q5 — reliable delivery with ARQ (automatic repeat request), plus the
/// Q2 relay that carries announcements between devices.
///
/// * Everything worth telling the server is written to an encrypted outbox
///   first, so nothing is lost offline.
/// * When a server is configured (build with
///   `--dart-define=AQUA_API_URL=https://your-server/api`), signing in on the
///   device also signs in to the server with the same details. Each item is
///   then sent with up to three attempts, a 5-second timeout each and
///   exponential back-off (1 s, 2 s). An Idempotency-Key makes a retry after
///   a lost acknowledgement harmless, and an HMAC signature made with the
///   session key the server issued proves the body was not changed (Q7).
/// * Every 20 seconds the app asks the server for new announcements and
///   completions, so a task posted on an educator's phone reaches the class.
///
/// Q11 — only HTTPS endpoints are accepted (TLS 1.2/1.3 negotiated by the
/// platform). Plain HTTP is allowed solely for a local server in debug builds.
class SyncService extends ChangeNotifier {
  SyncService({required SecureVault vault, String? baseUrl, http.Client? client})
      : _vault = vault,
        _client = client ?? http.Client(),
        baseUrl = normalizeBaseUrl(baseUrl ?? const String.fromEnvironment('AQUA_API_URL'));

  static const _slot = 'outbox';
  static const _stateSlot = 'syncState';
  static const _sessionSecret = 'aq.api.session.v1';
  static const _maxAttempts = 3;
  static const _timeout = Duration(seconds: 5);
  static const pollEvery = Duration(seconds: 20);

  final SecureVault _vault;
  final http.Client _client;

  /// Empty when no server is configured — the app then runs fully offline.
  final String baseUrl;
  final List<OutboxItem> _items = [];
  bool _flushing = false;
  DateTime? lastSyncAt;
  DateTime? lastPullAt;

  _ApiSession? _session;
  String? _userId;
  Timer? _poll;

  /// Newest server event already applied, per local user (people on a shared
  /// device can see different classes, so each keeps their own position).
  final Map<String, int> _lastSeq = {};

  /// The latest problem talking to the server, in words a person can act on.
  String? serverProblem;

  /// Receives announcements and completions from other devices.
  void Function(List<RemoteEvent> events)? onRemote;

  bool get isConfigured => baseUrl.isNotEmpty;
  bool get isFlushing => _flushing;
  List<OutboxItem> get items => List.unmodifiable(_items);
  int get pendingCount => _items.where((i) => i.status == OutboxStatus.pending).length;

  /// True when the signed-in person also has a live server session.
  bool get hasServerSession {
    final s = _session;
    return s != null && s.valid && s.localUserId == _userId;
  }

  /// HTTPS only (plain HTTP just for a local server in debug builds), with
  /// the `/api` prefix added if it was left off.
  @visibleForTesting
  static String normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    final u = Uri.tryParse(trimmed);
    if (trimmed.isEmpty || u == null || !u.hasAuthority) return '';
    final local = u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '10.0.2.2';
    if (!(u.scheme == 'https' || (kDebugMode && u.scheme == 'http' && local))) {
      debugPrint('Ignoring insecure API URL "$url" — HTTPS is required.');
      return '';
    }
    // Rebuild from parts so any query string or #fragment is dropped.
    var s = Uri(scheme: u.scheme, host: u.host, port: u.hasPort ? u.port : null, path: u.path).toString();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (!s.endsWith('/api')) s = '$s/api';
    return s;
  }

  /// Plain-language status for the Security Center.
  String describe() {
    if (!isConfigured) return 'Offline mode — $pendingCount item(s) kept in the encrypted outbox';
    if (!hasServerSession) {
      return 'Not signed in to the server${serverProblem == null ? '' : ' — $serverProblem'}. '
          '$pendingCount update(s) wait safely on this device.';
    }
    return '$pendingCount waiting · HTTPS only · each update signed with your session key and retried up to 3 times';
  }

  Future<void> load() async {
    final raw = await _vault.readJson(_slot);
    _items.clear();
    if (raw is List) {
      for (final e in raw) {
        try {
          _items.add(OutboxItem.fromJson((e as Map).cast<String, Object?>()));
        } catch (_) {}
      }
    }
    final state = await _vault.readJson(_stateSlot);
    if (state is Map) {
      final seqs = state['lastSeq'];
      if (seqs is Map) {
        for (final e in seqs.entries) {
          final k = e.key;
          final v = e.value;
          if (k is String && v is int) _lastSeq[k] = v;
        }
      }
    }
    _session = _ApiSession.decode(await _vault.readSecret(_sessionSecret));
    notifyListeners();
  }

  Future<void> _save() async {
    // Keep the outbox bounded: drop delivered items once it grows past 200.
    if (_items.length > 200) {
      _items.removeWhere((i) => i.status == OutboxStatus.sent);
    }
    await _vault.writeJson(_slot, _items.map((i) => i.toJson()).toList());
  }

  Future<void> enqueue(String kind, Map<String, Object?> payload) async {
    _items.add(OutboxItem(
      id: Crypto.b64url(Crypto.randomBytes(12)),
      kind: kind,
      payload: payload,
      createdAt: DateTime.now(),
      ownerId: _userId,
    ));
    await _save();
    notifyListeners();
    unawaited(flush());
  }

  // ------------------------------------------------------------ session ---

  /// Called by the auth service whenever the signed-in person changes.
  void bindUser(String? localUserId) {
    _userId = localUserId;
    _poll?.cancel();
    _poll = null;
    if (localUserId != null && isConfigured) {
      _poll = Timer.periodic(pollEvery, (_) => unawaited(syncNow()));
      unawaited(syncNow());
    }
    notifyListeners();
  }

  /// Signs in to the server with the details the person just typed.
  /// Best-effort: if the server can't be reached the app keeps working
  /// offline and the outbox waits.
  Future<void> signInToServer({
    required String localUserId,
    required String path,
    required Map<String, Object?> body,
  }) async {
    if (!isConfigured) return;
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) {
        serverProblem = switch (res.statusCode) {
          401 => 'the server does not know this account (accounts registered on this device stay on it)',
          429 => 'too many sign-in attempts on the server; try again later',
          _ => 'the server refused sign-in (${res.statusCode})',
        };
        notifyListeners();
        return;
      }
      final j = (jsonDecode(res.body) as Map).cast<String, Object?>();
      final session = _ApiSession(
        token: j['token']! as String,
        key: base64.decode(j['signingKey']! as String),
        expiresAt: DateTime.parse(j['expiresAt']! as String),
        localUserId: localUserId,
      );
      _session = session;
      await _vault.writeSecret(_sessionSecret, session.encode());
      serverProblem = null;
      notifyListeners();
      unawaited(syncNow());
    } on TimeoutException {
      serverProblem = 'the server did not answer';
      notifyListeners();
    } catch (_) {
      serverProblem = 'the server could not be reached';
      notifyListeners();
    }
  }

  /// Ends the server session too (best-effort) when the person signs out.
  Future<void> signOut() async {
    final s = _session;
    bindUser(null);
    _session = null;
    await _vault.deleteSecret(_sessionSecret);
    notifyListeners();
    if (s == null || !isConfigured) return;
    try {
      await _client
          .post(Uri.parse('$baseUrl/auth/logout'), headers: {'Authorization': 'Bearer ${s.token}'})
          .timeout(_timeout);
    } catch (_) {
      // The token expires on its own; nothing else to do offline.
    }
  }

  Future<void> _dropSession(String reason) async {
    _session = null;
    serverProblem = reason;
    await _vault.deleteSecret(_sessionSecret);
    notifyListeners();
  }

  /// Fetches news from other devices, then sends anything waiting.
  Future<void> syncNow() async {
    if (!hasServerSession) return;
    await pull();
    await flush();
  }

  // --------------------------------------------------------------- pull ---

  /// Q2 relay: announcements and completions posted on other devices.
  Future<void> pull() async {
    final session = _session;
    final user = _userId;
    if (!isConfigured || session == null || user == null || !hasServerSession) return;
    final since = _lastSeq[user] ?? 0;
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/announcements?since=$since'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      ).timeout(_timeout);
      if (res.statusCode == 401) {
        await _dropSession('your server session ended — sign in again to resume syncing');
        return;
      }
      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      final list = decoded is Map ? decoded['events'] : null;
      if (list is! List) return;
      final events = <RemoteEvent>[];
      var newest = since;
      for (final e in list) {
        if (e is! Map) continue;
        final seq = e['seq'];
        final type = e['type'];
        final data = e['data'];
        if (seq is! int || type is! String || data is! Map) continue;
        events.add(RemoteEvent(seq: seq, type: type, data: data.cast<String, Object?>()));
        if (seq > newest) newest = seq;
      }
      if (events.isNotEmpty) onRemote?.call(events);
      if (newest != since) {
        _lastSeq[user] = newest;
        await _vault.writeJson(_stateSlot, {'lastSeq': _lastSeq});
      }
      lastPullAt = DateTime.now();
      serverProblem = null;
      notifyListeners();
    } catch (_) {
      // Offline or timed out: the next tick tries again.
    }
  }

  // --------------------------------------------------------------- push ---

  /// Sends the signed-in person's pending items. Safe to call repeatedly
  /// (for example when the network comes back).
  Future<void> flush() async {
    final session = _session;
    if (!isConfigured || _flushing || session == null || !hasServerSession) return;
    _flushing = true;
    notifyListeners();
    try {
      // Loop until nothing of this person's is pending, so items queued while
      // a pass was already running go out now rather than on the next tick.
      var stop = false;
      while (!stop) {
        final mine = _items
            .where((i) => i.status == OutboxStatus.pending && (i.ownerId == null || i.ownerId == session.localUserId))
            .toList();
        if (mine.isEmpty) break;
        for (final item in mine) {
          final outcome = await _sendWithRetry(item, session);
          if (outcome == _Send.ok) {
            item.status = OutboxStatus.sent;
            item.lastError = null;
            lastSyncAt = DateTime.now();
          } else if (outcome == _Send.rejected) {
            item.status = OutboxStatus.rejected;
          }
          await _save();
          if (outcome == _Send.sessionEnded) {
            await _dropSession('your server session ended — sign in again to resume syncing');
            stop = true;
            break;
          }
          // Still offline after three tries: stop and wait for the next tick.
          if (outcome == _Send.retryLater) {
            stop = true;
            break;
          }
        }
      }
    } finally {
      _flushing = false;
      notifyListeners();
    }
  }

  Future<_Send> _sendWithRetry(OutboxItem item, _ApiSession session) async {
    final body = jsonEncode({
      'id': item.id,
      'kind': item.kind,
      'createdAt': item.createdAt.toUtc().toIso8601String(),
      'payload': item.payload,
    });
    final signature = Crypto.hex(await Crypto.hmacSha256(session.key, utf8.encode(body)));
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      item.attempts++;
      try {
        final res = await _client
            .post(
              Uri.parse('$baseUrl/sync/${Uri.encodeComponent(item.kind)}'),
              headers: {
                'Authorization': 'Bearer ${session.token}',
                'Content-Type': 'application/json',
                'Idempotency-Key': item.id,
                'X-Aqua-Signature': signature,
              },
              body: body,
            )
            .timeout(_timeout);
        if (res.statusCode >= 200 && res.statusCode < 300) return _Send.ok;
        if (res.statusCode == 401) {
          item.lastError = 'Server session ended';
          return _Send.sessionEnded;
        }
        final retryable = res.statusCode == 408 || res.statusCode == 429 || res.statusCode >= 500;
        item.lastError = _serverMessage(res) ?? 'Server answered ${res.statusCode}';
        if (!retryable) return _Send.rejected;
      } on TimeoutException {
        item.lastError = 'No acknowledgement within ${_timeout.inSeconds} s';
      } catch (_) {
        item.lastError = 'Network error';
      }
      if (attempt < _maxAttempts) {
        await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    }
    return _Send.retryLater;
  }

  static String? _serverMessage(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      final e = j is Map ? j['error'] : null;
      return e is String ? e : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _client.close();
    super.dispose();
  }
}
