/// Validation and sanitisation for everything a person can type.
///
/// Messages travel between students, educators and NGOs, so they are cleaned
/// of control characters and bidirectional-override characters (used in
/// "Trojan Source" style spoofing), trimmed and length-limited.
abstract final class InputRules {
  static const maxMessage = 500;
  static const maxName = 60;
  static const maxTitle = 120;

  static final RegExp _control = RegExp(
    '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F\u200B-\u200F\u202A-\u202E\u2066-\u2069]',
  );
  static final RegExp _manyNewlines = RegExp(r'\n{3,}');
  static final RegExp _email = RegExp(r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$");
  static final RegExp _personName = RegExp(r"^[\p{L}][\p{L}\p{M} .'\-]{0,59}$", unicode: true);
  static final RegExp _classCode = RegExp(r'^[A-Z]{3}-\d{4}-[A-Z]{2,5}$');
  static final RegExp _pin = RegExp(r'^\d{4}$');

  static const _commonPasswords = {
    'password', 'password1', 'password123', '123456789', '1234567890', 'qwertyuiop',
    'iloveyou', 'aquaaware', 'aquaaware1', 'welcome123', 'admin12345', 'letmein123',
  };

  /// Strips invisible/control characters, trims, collapses blank lines, caps length.
  static String clean(String input, {int max = maxMessage}) {
    var s = input.replaceAll(_control, '').replaceAll('\r\n', '\n').trim();
    s = s.replaceAll(_manyNewlines, '\n\n');
    if (s.length > max) s = s.substring(0, max).trimRight();
    return s;
  }

  static String? validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your email address.';
    if (v.length > 120 || !_email.hasMatch(v)) return 'Enter an email like name@school.org.';
    return null;
  }

  static String? validatePersonName(String? value) {
    final v = clean(value ?? '', max: maxName);
    if (v.length < 2) return 'Enter your name (at least 2 letters).';
    if (!_personName.hasMatch(v)) return 'Use letters, spaces, dots or hyphens only.';
    return null;
  }

  static String? validateClassCode(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return 'Enter the class code from your educator.';
    if (!_classCode.hasMatch(v)) return 'Class codes look like AWA-2024-GHS.';
    return null;
  }

  static String? validatePin(String? value, {bool isNew = false}) {
    final v = (value ?? '').trim();
    if (!_pin.hasMatch(v)) return 'Enter exactly 4 digits.';
    if (isNew && isTrivialPin(v)) return 'Pick a PIN that is harder to guess than $v.';
    return null;
  }

  static bool isTrivialPin(String pin) {
    if (RegExp(r'^(\d)\1{3}$').hasMatch(pin)) return true; // 1111
    const runs = '0123456789012';
    const back = '9876543210987';
    return runs.contains(pin) || back.contains(pin);
  }

  static String? validateRequired(String? value, String what, {int max = maxMessage}) {
    final v = clean(value ?? '', max: max);
    if (v.isEmpty) return 'Write $what first.';
    return null;
  }

  /// NIST SP 800-63B style: length first, then a light diversity check and a
  /// block-list of the most common choices.
  static String? validateNewPassword(String? value) {
    final v = value ?? '';
    if (v.length < 10) return 'Use at least 10 characters.';
    if (v.length > 128) return 'Use 128 characters or fewer.';
    if (_commonPasswords.contains(v.toLowerCase())) return 'That password is too common.';
    if (passwordScore(v) < 2) return 'Mix in numbers or symbols to make it stronger.';
    return null;
  }

  /// 0 (weak) to 4 (strong).
  static int passwordScore(String v) {
    if (v.isEmpty) return 0;
    var classes = 0;
    if (RegExp('[a-z]').hasMatch(v)) classes++;
    if (RegExp('[A-Z]').hasMatch(v)) classes++;
    if (RegExp(r'\d').hasMatch(v)) classes++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) classes++;
    var score = 0;
    if (v.length >= 10) score++;
    if (v.length >= 14) score++;
    if (classes >= 3) score++;
    if (classes == 4) score++;
    if (_commonPasswords.contains(v.toLowerCase())) score = 0;
    return score.clamp(0, 4);
  }

  /// Digits and an optional leading "+", 10–15 digits long; null when invalid.
  static String? normalizePhone(String phone) {
    final trimmed = phone.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 15) return null;
    return trimmed.startsWith('+') ? '+$digits' : digits;
  }

  /// "+91 98765 43210" → "+91 ••••• ••210". Personal numbers stay private
  /// until an educator deliberately reveals them.
  static String maskPhone(String phone) {
    final n = normalizePhone(phone);
    if (n == null) return 'Not available';
    final digits = n.replaceAll('+', '');
    final tail = digits.substring(digits.length - 3);
    final cc = n.startsWith('+') && digits.length > 10
        ? '+${digits.substring(0, digits.length - 10)} '
        : '';
    return '$cc••••• ••$tail';
  }
}
