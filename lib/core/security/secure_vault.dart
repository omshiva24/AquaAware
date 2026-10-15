// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crypto_service.dart';

/// Whether keys live in hardware-backed secure storage or only in memory.
enum VaultHealth { secure, volatile }

/// Encrypted key–value store (envelope encryption).
///
/// * Two random 256-bit keys are generated per install and kept in the
///   platform keystore (Android Keystore, iOS/macOS Keychain, Windows DPAPI,
///   Linux libsecret, WebCrypto on the web).
/// * App data is serialised to JSON, sealed with AES-256-GCM using the
///   data key, and only the ciphertext is written to shared preferences.
/// * The slot name is used as associated data, so a blob copied into a
///   different slot fails authentication.
///
/// If the platform keystore is unavailable the vault *fails closed*: it keeps
/// everything in memory for the session instead of writing keys in plain text.
class SecureVault {
  SecureVault._({
    required SharedPreferences? prefs,
    required FlutterSecureStorage secure,
    required List<int> dataKey,
    required this.macKey,
    required this.health,
    required this.keyFingerprint,
  })  : _prefs = prefs,
        _secure = secure,
        _dataKey = dataKey;

  static const _dataKeyName = 'aq.key.data.v1';
  static const _macKeyName = 'aq.key.mac.v1';
  static const _prefix = 'aq.vault.';

  final SharedPreferences? _prefs;
  final FlutterSecureStorage _secure;
  final List<int> _dataKey;

  /// Key for HMAC signatures (ledger chain, QR tokens, sync payloads).
  final List<int> macKey;
  final VaultHealth health;
  final String keyFingerprint;

  final Map<String, String> _memory = {};
  final Map<String, String> _memorySecrets = {};
  Future<void> _writeChain = Future<void>.value();

  /// Number of blobs that failed authentication since launch.
  int tamperEvents = 0;

  bool get isSecure => health == VaultHealth.secure;

  static Future<SecureVault> open() async {
    const secure = FlutterSecureStorage();
    var health = VaultHealth.secure;
    SharedPreferences? prefs;
    List<int> dataKey;
    List<int> macKey;
    try {
      dataKey = await _loadOrCreateKey(secure, _dataKeyName);
      macKey = await _loadOrCreateKey(secure, _macKeyName);
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Secure storage unavailable, running volatile: $e');
      health = VaultHealth.volatile;
      dataKey = Crypto.randomBytes(32);
      macKey = Crypto.randomBytes(32);
      prefs = null;
    }
    return SecureVault._(
      prefs: prefs,
      secure: secure,
      dataKey: dataKey,
      macKey: macKey,
      health: health,
      keyFingerprint: await Crypto.fingerprint(dataKey),
    );
  }

  static Future<List<int>> _loadOrCreateKey(FlutterSecureStorage s, String name) async {
    final existing = await s.read(key: name);
    if (existing != null) {
      final bytes = base64.decode(existing);
      if (bytes.length == 32) return bytes;
    }
    final fresh = Crypto.randomBytes(32);
    final encoded = base64.encode(fresh);
    await s.write(key: name, value: encoded);
    // Read back to be sure the keystore really persisted it.
    if (await s.read(key: name) != encoded) {
      throw StateError('Secure storage did not persist the key');
    }
    return fresh;
  }

  // ---------------------------------------------------------------- data ---

  Future<Object?> readJson(String slot) async {
    final raw = _prefs?.getString('$_prefix$slot') ?? _memory[slot];
    if (raw == null) return null;
    try {
      final clear = await Crypto.decrypt(
        _dataKey,
        base64.decode(raw),
        aad: utf8.encode(slot),
      );
      return jsonDecode(utf8.decode(clear));
    } catch (e) {
      // Authentication failure = the blob was modified outside the app.
      tamperEvents++;
      debugPrint('Vault slot "$slot" failed authentication and was ignored.');
      return null;
    }
  }

  Future<void> writeJson(String slot, Object? value) {
    // Serialise writes so a slow write can never overwrite a newer one.
    final next = _writeChain.then((_) async {
      final sealed = await Crypto.encrypt(
        _dataKey,
        utf8.encode(jsonEncode(value)),
        aad: utf8.encode(slot),
      );
      final encoded = base64.encode(sealed);
      final prefs = _prefs;
      if (prefs != null) {
        await prefs.setString('$_prefix$slot', encoded);
      } else {
        _memory[slot] = encoded;
      }
    });
    _writeChain = next.catchError((Object e) {
      debugPrint('Vault write failed for "$slot": $e');
    });
    return next;
  }

  Future<void> delete(String slot) async {
    _memory.remove(slot);
    await _prefs?.remove('$_prefix$slot');
  }

  // ------------------------------------------------------------- secrets ---

  /// Small secrets (session token) go straight to the platform keystore.
  Future<String?> readSecret(String key) async {
    if (!isSecure) return _memorySecrets[key];
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSecret(String key, String value) async {
    if (!isSecure) {
      _memorySecrets[key] = value;
      return;
    }
    await _secure.write(key: key, value: value);
  }

  Future<void> deleteSecret(String key) async {
    _memorySecrets.remove(key);
    if (!isSecure) return;
    try {
      await _secure.delete(key: key);
    } catch (_) {}
  }

  // ------------------------------------------------------------ checks -----

  /// Live proof for the Security Center: encrypt, decrypt, then confirm a
  /// single flipped bit is rejected.
  Future<bool> selfTest() async {
    try {
      final probe = utf8.encode('aquaaware-probe-${DateTime.now().microsecondsSinceEpoch}');
      final sealed = await Crypto.encrypt(_dataKey, probe, aad: utf8.encode('probe'));
      final opened = await Crypto.decrypt(_dataKey, sealed, aad: utf8.encode('probe'));
      if (!Crypto.constantTimeEquals(opened, probe)) return false;
      final tampered = List<int>.of(sealed);
      tampered[14] ^= 0x01;
      try {
        await Crypto.decrypt(_dataKey, tampered, aad: utf8.encode('probe'));
        return false; // tampering went unnoticed — fail the check
      } catch (_) {
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  /// Removes every vault slot (used by "Reset demo data").
  Future<void> wipeData() async {
    _memory.clear();
    final prefs = _prefs;
    if (prefs == null) return;
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await prefs.remove(k);
    }
  }
}
