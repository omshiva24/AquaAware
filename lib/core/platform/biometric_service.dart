import 'package:local_auth/local_auth.dart';

import 'capabilities.dart';

/// Q12 — biometric (or device PIN) confirmation for quick unlock.
abstract final class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    if (!Caps.canUseBiometrics) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> confirm(String reason) async {
    if (!Caps.canUseBiometrics) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // Not enrolled, cancelled, locked out, or (Android) MainActivity is not
      // a FlutterFragmentActivity — run tool/configure_platforms.dart.
      return false;
    }
  }
}
