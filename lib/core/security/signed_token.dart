import 'dart:convert';

import 'crypto_service.dart';

/// What a QR code is for. The kind is part of the signed header, so a
/// check-in code can never be replayed as a reward claim.
enum TokenKind { claim, checkin }

class SignedToken {
  const SignedToken({required this.kind, required this.payload, required this.raw});

  final TokenKind kind;
  final Map<String, Object?> payload;
  final String raw;

  String get nonce => payload['n']! as String;
  DateTime get expiresAt =>
      DateTime.fromMillisecondsSinceEpoch((payload['exp']! as int) * 1000);
  String? str(String key) => payload[key] as String?;
  int? integer(String key) => payload[key] as int?;
}

class TokenCheck {
  const TokenCheck.ok(SignedToken this.token) : error = null;
  const TokenCheck.fail(String this.error) : token = null;

  final SignedToken? token;
  final String? error;
  bool get isValid => token != null;
}

/// Q9 — QR anti-replay. Compact, JWT-like tokens:
///
///   AQ1.<kind>.<base64url(json payload)>.<base64url(HMAC-SHA256)>
///
/// The payload carries an issue time, an expiry and a 96-bit random nonce.
/// Verifiers check the HMAC in constant time, the expiry, and (in the
/// repository) that the nonce has never been redeemed before.
class TokenSigner {
  TokenSigner(this._key);

  final List<int> _key;
  static const _version = 'AQ1';
  static const _maxLength = 2048;
  static const _maxClockSkew = Duration(minutes: 2);

  Future<String> sign(
    TokenKind kind,
    Map<String, Object?> claims, {
    required Duration ttl,
    DateTime? now,
  }) async {
    final issued = (now ?? DateTime.now()).toUtc();
    final payload = <String, Object?>{
      ...claims,
      'iat': issued.millisecondsSinceEpoch ~/ 1000,
      'exp': issued.add(ttl).millisecondsSinceEpoch ~/ 1000,
      'n': Crypto.b64url(Crypto.randomBytes(12)),
    };
    final body = Crypto.b64url(utf8.encode(jsonEncode(payload)));
    final head = '$_version.${kind.name}.$body';
    final sig = await Crypto.hmacSha256(_key, utf8.encode(head));
    return '$head.${Crypto.b64url(sig)}';
  }

  Future<TokenCheck> verify(String raw, {required TokenKind expect, DateTime? now}) async {
    final text = raw.trim();
    if (text.isEmpty) return const TokenCheck.fail('No code was found.');
    if (text.length > _maxLength) {
      return const TokenCheck.fail('This code is too long to be an AquaAware code.');
    }
    final parts = text.split('.');
    if (parts.length != 4 || parts[0] != _version) {
      return const TokenCheck.fail('This is not an AquaAware code.');
    }
    if (parts[1] != expect.name) {
      return TokenCheck.fail(expect == TokenKind.claim
          ? 'This is an event check-in code. Open "Scan" from the student app to use it.'
          : 'This is a reward claim. Only the NGO desk can redeem it.');
    }

    final head = '${parts[0]}.${parts[1]}.${parts[2]}';
    List<int> sig;
    try {
      sig = Crypto.b64urlDecode(parts[3]);
    } catch (_) {
      return const TokenCheck.fail('The code is damaged. Try scanning again.');
    }
    final expected = await Crypto.hmacSha256(_key, utf8.encode(head));
    if (!Crypto.constantTimeEquals(sig, expected)) {
      return const TokenCheck.fail(
          'Signature check failed. The code was altered or issued by a different device.');
    }

    Map<String, Object?> payload;
    try {
      final decoded = jsonDecode(utf8.decode(Crypto.b64urlDecode(parts[2])));
      payload = (decoded as Map).cast<String, Object?>();
    } catch (_) {
      return const TokenCheck.fail('The code is damaged. Try scanning again.');
    }

    final exp = payload['exp'];
    final iat = payload['iat'];
    final nonce = payload['n'];
    if (exp is! int || iat is! int || nonce is! String) {
      return const TokenCheck.fail('The code is missing required fields.');
    }
    final nowSec = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    if (iat - nowSec > _maxClockSkew.inSeconds) {
      return const TokenCheck.fail('This code was issued in the future. Check the device clock.');
    }
    if (nowSec > exp) {
      return const TokenCheck.fail('This code has expired. Ask for a fresh one.');
    }
    return TokenCheck.ok(SignedToken(kind: expect, payload: payload, raw: text));
  }
}
