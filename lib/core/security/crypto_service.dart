import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Thin, audited wrapper around `package:cryptography`.
///
/// Q7 (CIA triad) — confidentiality comes from AES-256-GCM, integrity from
/// HMAC-SHA256 (a *keyed* hash: unlike the plain SHA-256 used before, an
/// attacker cannot recompute it after tampering with data).
abstract final class Crypto {
  static final Random _rng = Random.secure();
  static final AesGcm _aes = AesGcm.with256bits();
  static final Hmac _hmac = Hmac.sha256();

  /// Cryptographically secure random bytes (never `Math.random`).
  static Uint8List randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  /// URL-safe base64 without padding — safe inside QR codes and URLs.
  static String b64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List b64urlDecode(String input) {
    var s = input.replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s += '=';
    }
    return base64.decode(s);
  }

  static String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Future<List<int>> sha256(List<int> data) async =>
      (await Sha256().hash(data)).bytes;

  static Future<String> sha256Hex(String text) async =>
      hex(await sha256(utf8.encode(text)));

  static Future<List<int>> hmacSha256(List<int> key, List<int> data) async {
    final mac = await _hmac.calculateMac(data, secretKey: SecretKey(key));
    return mac.bytes;
  }

  /// Compares two byte lists in constant time to avoid timing side channels.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// AES-256-GCM. Output layout: nonce(12) | ciphertext | tag(16).
  /// [aad] binds the ciphertext to its storage slot so blobs cannot be swapped.
  static Future<Uint8List> encrypt(List<int> key, List<int> plain, {List<int> aad = const []}) async {
    final nonce = randomBytes(12);
    final box = await _aes.encrypt(
      plain,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: aad,
    );
    final out = BytesBuilder(copy: false)
      ..add(nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  /// Throws [SecretBoxAuthenticationError] if the data was tampered with.
  static Future<Uint8List> decrypt(List<int> key, List<int> sealed, {List<int> aad = const []}) async {
    if (sealed.length < 12 + 16) {
      throw const FormatException('Ciphertext too short');
    }
    final nonce = sealed.sublist(0, 12);
    final mac = sealed.sublist(sealed.length - 16);
    final cipherText = sealed.sublist(12, sealed.length - 16);
    final clear = await _aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(key),
      aad: aad,
    );
    return Uint8List.fromList(clear);
  }

  /// Short, human-checkable fingerprint of a key (first 8 bytes of SHA-256).
  static Future<String> fingerprint(List<int> key) async {
    final h = await sha256(key);
    final hx = hex(h.sublist(0, 8)).toUpperCase();
    return [for (var i = 0; i < hx.length; i += 4) hx.substring(i, i + 4)].join(' ');
  }
}

/// PBKDF2-HMAC-SHA256 password hashing with per-user salt.
///
/// Encoded as `pbkdf2-sha256$<iterations>$<salt b64>$<hash b64>` so the
/// iteration count can be raised later without breaking stored hashes.
abstract final class PasswordHasher {
  static const int iterations = 100000;
  static const String _scheme = 'pbkdf2-sha256';

  static Future<String> hash(String secret) async {
    final salt = Crypto.randomBytes(16);
    final dk = await _derive(secret, salt, iterations);
    return '$_scheme\$$iterations\$${base64.encode(salt)}\$${base64.encode(dk)}';
  }

  static Future<bool> verify(String secret, String encoded) async {
    final parts = encoded.split(r'$');
    if (parts.length != 4 || parts[0] != _scheme) return false;
    final iter = int.tryParse(parts[1]);
    if (iter == null || iter < 10000) return false;
    final salt = base64.decode(parts[2]);
    final expected = base64.decode(parts[3]);
    final actual = await _derive(secret, salt, iter);
    return Crypto.constantTimeEquals(actual, expected);
  }

  static Future<List<int>> _derive(String secret, List<int> salt, int iter) {
    final args = <String, Object>{'p': secret, 's': salt, 'i': iter};
    // Native: run in a background isolate so the UI stays at 60 fps.
    // Web: compute() runs inline, and the browser's WebCrypto does the work.
    return compute(_pbkdf2Worker, args);
  }
}

/// Top-level so it can run inside an isolate.
Future<List<int>> _pbkdf2Worker(Map<String, Object> args) async {
  final kdf = Pbkdf2.hmacSha256(iterations: args['i']! as int, bits: 256);
  final key = await kdf.deriveKeyFromPassword(
    password: args['p']! as String,
    nonce: (args['s']! as List<Object?>).cast<int>(),
  );
  return key.extractBytes();
}
