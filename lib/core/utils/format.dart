// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.
/// Small, dependency-free date and number formatting.
abstract final class Fmt {
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'am' : 'pm'}';
  }

  static String date(DateTime t) => '${t.day} ${_months[t.month - 1]} ${t.year}';

  static String shortDate(DateTime t) => '${t.day} ${_months[t.month - 1]}';

  static String weekday(DateTime t) => _days[t.weekday - 1];

  /// "just now", "5 min ago", "3 h ago", "yesterday", "12 Oct".
  static String relative(DateTime t, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final d = n.difference(t);
    if (d.isNegative || d.inSeconds < 45) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24 && n.day == t.day) return '${d.inHours} h ago';
    final yesterday = DateTime(n.year, n.month, n.day).subtract(const Duration(days: 1));
    if (t.isAfter(yesterday)) return 'yesterday';
    return shortDate(t);
  }

  static String duration(Duration d) {
    if (d.inDays >= 1) return '${d.inDays} d ${d.inHours % 24} h';
    if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes % 60} min';
    if (d.inMinutes >= 1) return '${d.inMinutes} min';
    return '${d.inSeconds.clamp(0, 59)} s';
  }

  /// 12345 → "12,345" (Indian grouping is used for 1 lakh and above).
  static String number(int n) {
    final neg = n < 0;
    final s = n.abs().toString();
    if (s.length <= 3) return neg ? '-$s' : s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    final out = '${groups.join(',')},$last3';
    return neg ? '-$out' : out;
  }

  static String dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  static String plural(int n, String one, [String? many]) =>
      '$n ${n == 1 ? one : (many ?? '${one}s')}';
}
