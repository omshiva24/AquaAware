import 'dart:convert';

import 'crypto_service.dart';

/// One immutable line in the points ledger.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.userId,
    required this.delta,
    required this.reason,
    required this.refKey,
    required this.at,
    required this.prevHash,
    required this.hash,
  });

  final String id;
  final String userId;
  final int delta;
  final String reason;

  /// Idempotency key: the same refKey can only ever earn points once per user.
  final String refKey;
  final DateTime at;
  final String prevHash;
  final String hash;

  String canonical() =>
      '$id|$userId|$delta|${base64.encode(utf8.encode(reason))}|$refKey|${at.millisecondsSinceEpoch}|$prevHash';

  Map<String, Object?> toJson() => {
        'id': id,
        'u': userId,
        'd': delta,
        'r': reason,
        'k': refKey,
        't': at.millisecondsSinceEpoch,
        'p': prevHash,
        'h': hash,
      };

  factory LedgerEntry.fromJson(Map<String, Object?> j) => LedgerEntry(
        id: j['id']! as String,
        userId: j['u']! as String,
        delta: j['d']! as int,
        reason: j['r']! as String,
        refKey: j['k']! as String,
        at: DateTime.fromMillisecondsSinceEpoch(j['t']! as int),
        prevHash: j['p']! as String,
        hash: j['h']! as String,
      );
}

/// Q3 + Q7 — a tamper-evident, hash-chained points ledger.
///
/// Points are never stored as a single editable number. Every award or
/// redemption is an entry whose HMAC covers the previous entry's hash, so
/// editing, deleting or re-ordering any past entry breaks the chain from
/// that point on. Because entries are keyed by user id rather than school,
/// a student's points and badges follow them when they change class.
abstract final class LedgerChain {
  static final String genesis = '0' * 64;

  static Future<LedgerEntry> seal({
    required List<int> key,
    required String prevHash,
    required String userId,
    required int delta,
    required String reason,
    required String refKey,
    DateTime? at,
  }) async {
    final draft = LedgerEntry(
      id: Crypto.b64url(Crypto.randomBytes(9)),
      userId: userId,
      delta: delta,
      reason: reason,
      refKey: refKey,
      at: at ?? DateTime.now(),
      prevHash: prevHash,
      hash: '',
    );
    final mac = await Crypto.hmacSha256(key, utf8.encode(draft.canonical()));
    return LedgerEntry(
      id: draft.id,
      userId: draft.userId,
      delta: draft.delta,
      reason: draft.reason,
      refKey: draft.refKey,
      at: draft.at,
      prevHash: draft.prevHash,
      hash: Crypto.hex(mac),
    );
  }

  /// Returns the index of the first broken entry, or -1 if the chain is intact.
  static Future<int> firstBrokenIndex(List<LedgerEntry> chain, List<int> key) async {
    var prev = genesis;
    for (var i = 0; i < chain.length; i++) {
      final e = chain[i];
      if (e.prevHash != prev) return i;
      final mac = await Crypto.hmacSha256(key, utf8.encode(e.canonical()));
      if (!Crypto.constantTimeEquals(utf8.encode(Crypto.hex(mac)), utf8.encode(e.hash))) {
        return i;
      }
      prev = e.hash;
    }
    return -1;
  }
}
