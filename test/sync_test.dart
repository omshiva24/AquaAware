// Tests for the outbox and server relay (Q2, Q5, Q7, Q11) against a fake
// server, so they run anywhere with `flutter test test/sync_test.dart`.

import 'dart:convert';

import 'package:aquaaware/core/net/sync_service.dart';
import 'package:aquaaware/core/security/crypto_service.dart';
import 'package:aquaaware/core/security/secure_vault.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _key = List<int>.generate(32, (i) => i * 7 % 256);

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

http.Response _signIn() => _json({
      'token': 'header.claims.signature',
      'signingKey': base64.encode(_key),
      'expiresAt': DateTime.now().add(const Duration(hours: 8)).toUtc().toIso8601String(),
      'user': {'id': 'STU002'},
    });

/// Waits for background sends (they include real back-off delays).
Future<void> _until(bool Function() done, {Duration limit = const Duration(seconds: 10)}) async {
  final end = DateTime.now().add(limit);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<SyncService> make(MockClient client) async {
    final vault = await SecureVault.open();
    final sync = SyncService(vault: vault, baseUrl: 'https://api.example.org', client: client);
    await sync.load();
    addTearDown(sync.dispose);
    return sync;
  }

  test('only HTTPS servers are accepted, and /api is added', () {
    expect(SyncService.normalizeBaseUrl('https://api.example.org'), 'https://api.example.org/api');
    expect(SyncService.normalizeBaseUrl('https://api.example.org:8443/api/'), 'https://api.example.org:8443/api');
    expect(SyncService.normalizeBaseUrl('https://api.example.org/?x=1#top'), 'https://api.example.org/api');
    expect(SyncService.normalizeBaseUrl('http://evil.example.org'), '', reason: 'plain HTTP to the internet');
    expect(SyncService.normalizeBaseUrl('ftp://example.org'), '');
    expect(SyncService.normalizeBaseUrl(''), '');
    // Tests run in debug mode, where a local development server is allowed.
    expect(SyncService.normalizeBaseUrl('http://127.0.0.1:8443'), 'http://127.0.0.1:8443/api');
  });

  test('without a server everything stays in the encrypted outbox', () async {
    final vault = await SecureVault.open();
    final sync = SyncService(vault: vault, baseUrl: '');
    addTearDown(sync.dispose);
    await sync.load();
    sync.bindUser('STU002');
    await sync.enqueue('quiz_score', {'moduleId': 'MOD_A', 'correct': 7, 'total': 10});
    expect(sync.isConfigured, isFalse);
    expect(sync.pendingCount, 1);
    expect(sync.describe(), contains('Offline mode'));
  });

  test('sends only the signed-in person’s items, signed with the session key', () async {
    final sent = <http.Request>[];
    final sync = await make(MockClient((req) async {
      if (req.url.path == '/api/auth/student') return _signIn();
      if (req.url.path == '/api/announcements') return _json({'events': <Object>[]});
      sent.add(req);
      return _json({'ok': true}, 201);
    }));

    sync.bindUser('STU002');
    await sync.enqueue('quiz_score', {'moduleId': 'MOD_A', 'correct': 7, 'total': 10});
    // Someone else uses the same classroom device before Priya reconnects.
    sync.bindUser('STU999');
    await sync.enqueue('quiz_score', {'moduleId': 'MOD_B', 'correct': 2, 'total': 10});
    sync.bindUser('STU002');

    await sync.signInToServer(localUserId: 'STU002', path: '/auth/student', body: {'name': 'Priya'});
    expect(sync.hasServerSession, isTrue);
    await _until(() => sent.isNotEmpty && !sync.isFlushing);

    expect(sent, hasLength(1), reason: 'the other student’s item is never sent in Priya’s name');
    expect(sync.pendingCount, 1);
    final req = sent.single;
    final body = jsonDecode(req.body) as Map<String, Object?>;
    expect(req.url.path, '/api/sync/quiz_score');
    expect(req.headers['Authorization'], 'Bearer header.claims.signature');
    expect(req.headers['Idempotency-Key'], body['id']);
    final expected = Crypto.hex(await Crypto.hmacSha256(_key, utf8.encode(req.body)));
    expect(req.headers['X-Aqua-Signature'], expected, reason: 'HMAC with the server-issued key (Q7)');
  });

  test('retries server errors with the same idempotency key (ARQ)', () async {
    final keys = <String?>[];
    var calls = 0;
    final sync = await make(MockClient((req) async {
      if (req.url.path == '/api/auth/staff') return _signIn();
      if (req.url.path == '/api/announcements') return _json({'events': <Object>[]});
      keys.add(req.headers['Idempotency-Key']);
      calls++;
      return calls < 3 ? _json({'error': 'busy'}, 503) : _json({'ok': true}, 201);
    }));
    sync.bindUser('EDU001');
    await sync.signInToServer(localUserId: 'EDU001', path: '/auth/staff', body: const {});
    await sync.enqueue('announcement', {'id': 'ANN-test-0001', 'message': 'Hi', 'audience': 'AWA-2024-GHS'});
    await _until(() => sync.pendingCount == 0 && !sync.isFlushing);

    expect(calls, 3);
    expect(keys.toSet(), hasLength(1), reason: 'every retry carries the same key, so the server applies it once');
    expect(sync.items.single.status, OutboxStatus.sent);
  });

  test('a refused update is not retried; an ended session keeps items safe', () async {
    var phase = 0;
    final sync = await make(MockClient((req) async {
      if (req.url.path == '/api/auth/student') return _signIn();
      if (req.url.path == '/api/announcements') return _json({'events': <Object>[]});
      return phase == 0
          ? _json({'error': 'Points can only be given for a known achievement.'}, 422)
          : _json({'error': 'Sign in first.'}, 401);
    }));
    sync.bindUser('STU002');
    await sync.signInToServer(localUserId: 'STU002', path: '/auth/student', body: const {});

    await sync.enqueue('points', {'delta': 99, 'reason': 'x', 'ref': 'made-up'});
    await _until(() => sync.items.isNotEmpty && sync.items.first.status == OutboxStatus.rejected);
    expect(sync.items.first.attempts, 1);
    expect(sync.items.first.lastError, contains('known achievement'));

    phase = 1;
    await sync.enqueue('quiz_score', {'moduleId': 'MOD_A', 'correct': 7, 'total': 10});
    await _until(() => !sync.hasServerSession);
    expect(sync.pendingCount, 1, reason: 'kept until the person signs in again');
    expect(sync.describe(), contains('Not signed in to the server'));
  });

  test('pulls announcements from other devices and remembers where it stopped', () async {
    final sinces = <String?>[];
    final received = <RemoteEvent>[];
    final sync = await make(MockClient((req) async {
      if (req.url.path == '/api/auth/student') return _signIn();
      if (req.url.path == '/api/announcements') {
        sinces.add(req.url.queryParameters['since']);
        return _json({
          'events': [
            {
              'seq': 7,
              'type': 'announcement',
              'data': {'id': 'ANN-remote-01', 'message': 'Hello', 'audience': 'ALL', 'senderRole': 'ngo'},
            },
            {'seq': 'bad', 'type': 'announcement', 'data': <String, Object?>{}},
          ],
        });
      }
      return _json({'ok': true}, 201);
    }));
    sync.onRemote = received.addAll;
    sync.bindUser('STU002');
    await sync.signInToServer(localUserId: 'STU002', path: '/auth/student', body: const {});
    await _until(() => received.isNotEmpty);
    await sync.pull();

    expect(received.first.data['id'], 'ANN-remote-01');
    expect(received.where((e) => e.seq == 7), isNotEmpty);
    expect(sinces.first, '0');
    expect(sinces.last, '7', reason: 'asks only for newer events next time');
  });
}
