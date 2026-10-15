// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'package:flutter/foundation.dart';

/// What the current platform can do. Screens use this to offer the right
/// fallback (for example "paste a code" where no camera scanner exists)
/// instead of failing at runtime.
abstract final class Caps {
  static TargetPlatform get _os => defaultTargetPlatform;

  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && _os == TargetPlatform.android;
  static bool get isIOS => !kIsWeb && _os == TargetPlatform.iOS;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop =>
      !kIsWeb &&
      (_os == TargetPlatform.windows || _os == TargetPlatform.macOS || _os == TargetPlatform.linux);

  /// mobile_scanner: Android, iOS, macOS and web.
  static bool get canScanWithCamera => kIsWeb || isMobile || _os == TargetPlatform.macOS;

  /// local_auth: Android, iOS, macOS and Windows.
  static bool get canUseBiometrics =>
      !kIsWeb && (isMobile || _os == TargetPlatform.macOS || _os == TargetPlatform.windows);

  /// flutter_tts: Android, iOS, macOS, Windows and web.
  static bool get canSpeak =>
      kIsWeb || isMobile || _os == TargetPlatform.macOS || _os == TargetPlatform.windows;

  /// geolocator: every platform (Linux needs GeoClue).
  static bool get canLocate => true;

  /// Opening a local file in another app needs a file system.
  static bool get canOpenLocalFiles => !kIsWeb;

  static String get platformName {
    if (kIsWeb) return 'Web';
    switch (_os) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}
