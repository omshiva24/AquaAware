import 'dart:convert';

import 'package:aquaaware/core/security/crypto_service.dart';
import 'package:aquaaware/core/security/file_rules.dart';
import 'package:aquaaware/core/security/input_rules.dart';
import 'package:aquaaware/core/security/ledger.dart';
import 'package:aquaaware/core/security/signed_token.dart';
import 'package:aquaaware/data/models/models.dart';
import 'package:aquaaware/data/seed/community_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AES-256-GCM (Q7 confidentiality)', () {
    test('round-trips and rejects a flipped bit or a different slot', () async {
      final key = Crypto.randomBytes(32);
      final slot = utf8.encode('students');
      final sealed = await Crypto.encrypt(key, utf8.encode('hello reservoir'), aad: slot);
      expect(utf8.decode(await Crypto.decrypt(key, sealed, aad: slot)), 'hello reservoir');

      final tampered = List<int>.of(sealed)..[14] ^= 0x01;
      await expectLater(Crypto.decrypt(key, tampered, aad: slot), throwsA(anything));
      await expectLater(Crypto.decrypt(key, sealed, aad: utf8.encode('claims')), throwsA(anything));
    });

    test('uses a fresh nonce every time', () async {
      final key = Crypto.randomBytes(32);
      final a = await Crypto.encrypt(key, utf8.encode('same'));
      final b = await Crypto.encrypt(key, utf8.encode('same'));
      expect(a, isNot(equals(b)));
    });
  });

  group('PBKDF2 password hashing', () {
    test('demo hashes match the documented demo secrets', () async {
      final byLogin = {for (final a in CommunitySeed.accounts()) a.loginId: a};
      const demo = {
        'kavitha@aquaaware.org': 'Kavitha#2026',
        'rajan@aquaaware.org': 'Rajan#2026',
        'admin@aquaaware.org': 'Manager#2026!',
        'NGO001': 'PSF-GREEN-2026',
        'NGO002': 'CEAD-GREEN-2026',
        'NGO003': 'SEVA-GREEN-2026',
        'NGO004': 'PMSSS-GREEN-2026',
        'NGO005': 'PSSSRF-GREEN-2026',
      };
      for (final e in demo.entries) {
        expect(await PasswordHasher.verify(e.value, byLogin[e.key]!.secretHash), isTrue, reason: e.key);
      }
      expect(await PasswordHasher.verify('wrong-password', byLogin['kavitha@aquaaware.org']!.secretHash), isFalse);
    });

    test('new hashes are salted and verify', () async {
      final a = await PasswordHasher.hash('2580');
      final b = await PasswordHasher.hash('2580');
      expect(a, isNot(equals(b)));
      expect(await PasswordHasher.verify('2580', a), isTrue);
      expect(await PasswordHasher.verify('2581', a), isFalse);
      expect(await PasswordHasher.verify('2580', 'md5\$1\$abc\$def'), isFalse);
    });
  });

  group('Signed QR tokens (Q9 anti-replay)', () {
    final signer = TokenSigner(List<int>.generate(32, (i) => i));
    final now = DateTime.utc(2026, 10, 12, 10);

    test('valid token verifies and carries its claims', () async {
      final t = await signer.sign(TokenKind.claim, {'cid': 'CLM-1', 'pts': 50}, ttl: const Duration(days: 7), now: now);
      final r = await signer.verify(t, expect: TokenKind.claim, now: now.add(const Duration(hours: 1)));
      expect(r.isValid, isTrue);
      expect(r.token!.str('cid'), 'CLM-1');
      expect(r.token!.integer('pts'), 50);
    });

    test('edited payload, wrong kind, expiry and foreign keys are refused', () async {
      final t = await signer.sign(TokenKind.claim, {'cid': 'CLM-1', 'pts': 50}, ttl: const Duration(days: 7), now: now);
      final parts = t.split('.');
      final payload = jsonDecode(utf8.decode(Crypto.b64urlDecode(parts[2]))) as Map<String, Object?>;
      payload['pts'] = 5000;
      final forged = [parts[0], parts[1], Crypto.b64url(utf8.encode(jsonEncode(payload))), parts[3]].join('.');
      expect((await signer.verify(forged, expect: TokenKind.claim, now: now)).isValid, isFalse);

      expect((await signer.verify(t, expect: TokenKind.checkin, now: now)).isValid, isFalse);
      expect((await signer.verify(t, expect: TokenKind.claim, now: now.add(const Duration(days: 8)))).isValid, isFalse);

      final other = TokenSigner(List<int>.filled(32, 7));
      expect((await other.verify(t, expect: TokenKind.claim, now: now)).isValid, isFalse);
      expect((await signer.verify('not a code', expect: TokenKind.claim, now: now)).isValid, isFalse);
    });

    test('codes issued in the future are refused', () async {
      final t = await signer.sign(TokenKind.checkin, {'act': 'A1'}, ttl: const Duration(minutes: 15), now: now.add(const Duration(hours: 1)));
      expect((await signer.verify(t, expect: TokenKind.checkin, now: now)).isValid, isFalse);
    });
  });

  group('Hash-chained points ledger (Q3 + Q7 integrity)', () {
    final key = List<int>.generate(32, (i) => 255 - i);

    Future<List<LedgerEntry>> chain() async {
      final out = <LedgerEntry>[];
      for (var i = 0; i < 3; i++) {
        out.add(await LedgerChain.seal(
          key: key,
          prevHash: out.isEmpty ? LedgerChain.genesis : out.last.hash,
          userId: 'STU001',
          delta: 10 * (i + 1),
          reason: 'Entry $i',
          refKey: 'ref:$i',
          at: DateTime(2026, 10, 1 + i),
        ));
      }
      return out;
    }

    test('an untouched chain verifies', () async {
      expect(await LedgerChain.firstBrokenIndex(await chain(), key), -1);
    });

    test('editing an amount is detected at that entry', () async {
      final c = await chain();
      final e = c[1];
      c[1] = LedgerEntry(
        id: e.id,
        userId: e.userId,
        delta: 9999, // the edit
        reason: e.reason,
        refKey: e.refKey,
        at: e.at,
        prevHash: e.prevHash,
        hash: e.hash,
      );
      expect(await LedgerChain.firstBrokenIndex(c, key), 1);
    });

    test('deleting an entry is detected', () async {
      final c = await chain()..removeAt(1);
      expect(await LedgerChain.firstBrokenIndex(c, key), 1);
    });
  });

  group('Input rules', () {
    test('strips invisible and bidirectional-override characters', () {
      expect(InputRules.clean('Hi\u202Eevil\u200B there\u0007'), 'Hievil there');
      expect(InputRules.clean('a' * 600).length, InputRules.maxMessage);
    });

    test('class codes, PINs and passwords', () {
      expect(InputRules.validateClassCode('awa-2024-ghs'), isNull);
      expect(InputRules.validateClassCode('AWA2024'), isNotNull);
      expect(InputRules.isTrivialPin('1111'), isTrue);
      expect(InputRules.isTrivialPin('1234'), isTrue);
      expect(InputRules.isTrivialPin('4321'), isTrue);
      expect(InputRules.isTrivialPin('2580'), isFalse);
      expect(InputRules.validateNewPassword('short'), isNotNull);
      expect(InputRules.validateNewPassword('password123'), isNotNull);
      expect(InputRules.validateNewPassword('Monsoon rain 2026!'), isNull);
    });

    test('phone numbers are masked', () {
      expect(InputRules.maskPhone('+91 98765 43210'), '+91 ••••• ••210');
      expect(InputRules.maskPhone('abc'), 'Not available');
    });
  });

  group('Shared files', () {
    test('content must match the extension (magic numbers)', () {
      final pdf = utf8.encode('%PDF-1.7\n...');
      final zip = [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00];
      final ole = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0x00];
      final exe = [0x4D, 0x5A, 0x90, 0x00]; // "MZ" — a Windows program
      expect(FileRules.contentMatches('pdf', pdf), isTrue);
      expect(FileRules.contentMatches('PDF', pdf), isTrue);
      expect(FileRules.contentMatches('docx', zip), isTrue);
      expect(FileRules.contentMatches('ppt', ole), isTrue);
      expect(FileRules.contentMatches('txt', utf8.encode('Rainwater notes')), isTrue);
      expect(FileRules.contentMatches('pdf', exe), isFalse, reason: 'renamed program');
      expect(FileRules.contentMatches('pdf', zip), isFalse);
      expect(FileRules.contentMatches('txt', exe), isFalse, reason: 'binary with NUL bytes');
      expect(FileRules.contentMatches('txt', const []), isFalse, reason: 'empty file');
      expect(FileRules.contentMatches('exe', exe), isFalse, reason: 'type not allowed');
    });
  });

  test('roles cannot be confused by a session string', () {
    expect(Role.values.byName('manager'), Role.manager);
    expect(() => Role.values.byName('admin'), throwsArgumentError);
  });
}
