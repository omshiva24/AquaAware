// Configures the native folders that `flutter create` generates, so every
// plugin AquaAware uses has the permissions and settings it needs.
//
// Run from the project root, after `flutter create` (setup.sh / setup.ps1 do
// both for you):
//
//   dart run tool/configure_platforms.dart
//
// Safe to run more than once: each change is skipped if it is already there.

import 'dart:convert';
import 'dart:io';

var _changed = 0;
final _notes = <String>[];

void main() {
  if (!File('pubspec.yaml').existsSync() || !File('lib/main.dart').existsSync()) {
    stderr.writeln('Run this from the AquaAware project root (the folder with pubspec.yaml).');
    exit(1);
  }
  _removeTemplateTest();
  _android();
  _ios();
  _macos();
  _web();
  _desktopTitles();
  _toolChecks();

  stdout.writeln('');
  stdout.writeln(_changed == 0 ? 'Everything was already configured.' : 'Applied $_changed change(s).');
  if (_notes.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('Before you build:');
    for (final n in _notes) {
      stdout.writeln('  - $n');
    }
  }
}

// ------------------------------------------------------------------ helpers

void _section(String name) => stdout.writeln('\n$name');

/// Applies [edit] to [path]; prints what happened.
void _patch(String path, String what, String Function(String text) edit) {
  final f = File(path);
  if (!f.existsSync()) {
    stdout.writeln('  - $what: $path not found (platform not created?)');
    return;
  }
  final before = f.readAsStringSync();
  final after = edit(before);
  if (after == before) {
    stdout.writeln('  [ok]   $what (already done)');
    return;
  }
  f.writeAsStringSync(after);
  _changed++;
  stdout.writeln('  [done] $what');
}

/// Inserts [snippet] just before the last occurrence of [closing].
String _beforeLast(String text, String closing, String snippet) {
  final i = text.lastIndexOf(closing);
  if (i < 0) return text;
  return text.replaceRange(i, i, snippet);
}

/// Adds plist keys (with their XML values) that are not there yet.
String _plistKeys(String plist, Map<String, String> entries) {
  final add = StringBuffer();
  entries.forEach((key, value) {
    if (!plist.contains('<key>$key</key>')) {
      add
        ..write('\t<key>$key</key>\n')
        ..write('\t$value\n');
    }
  });
  if (add.isEmpty) return plist;
  return _beforeLast(plist, '</dict>', add.toString());
}

String _string(String s) => '<string>$s</string>';

// ------------------------------------------------------------- templates ---

/// `flutter create` adds a counter-app test that does not compile here.
void _removeTemplateTest() {
  final f = File('test/widget_test.dart');
  if (f.existsSync() && f.readAsStringSync().contains('MyApp')) {
    f.deleteSync();
    _changed++;
    stdout.writeln('[done] Removed the template test/widget_test.dart (AquaAware has its own tests)');
  }
}

// --------------------------------------------------------------- Android ---

void _android() {
  if (!Directory('android').existsSync()) return;
  _section('Android');

  const permissions = [
    'android.permission.INTERNET', // release builds need it explicitly
    'android.permission.ACCESS_NETWORK_STATE', // connectivity (Q1)
    'android.permission.CAMERA', // QR scanning
    'android.permission.ACCESS_FINE_LOCATION', // nearest collectors, reward desk (Q8)
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.USE_BIOMETRIC', // staff quick unlock (Q12)
  ];

  _patch('android/app/src/main/AndroidManifest.xml', 'Permissions, backup and package queries', (xml) {
    var out = xml;

    final perms = StringBuffer();
    for (final p in permissions) {
      if (!out.contains('android:name="$p"')) perms.write('\n    <uses-permission android:name="$p"/>');
    }
    if (!out.contains('android.hardware.camera"')) {
      // Devices without a camera can still install the app and paste codes.
      perms.write('\n    <uses-feature android:name="android.hardware.camera" android:required="false"/>');
    }
    if (perms.isNotEmpty) {
      final open = RegExp(r'<manifest[^>]*>').firstMatch(out);
      if (open != null) out = out.replaceRange(open.end, open.end, perms.toString());
    }

    // Encrypted data is useless without the keystore keys, which are never
    // backed up; restoring a backup would only produce unreadable data.
    if (!out.contains('android:allowBackup')) {
      out = out.replaceFirst('<application', '<application\n        android:allowBackup="false"');
    }

    if (!out.contains('android.intent.action.TTS_SERVICE')) {
      const intents = '''
        <!-- AquaAware: links, calls, SMS and e-mail (url_launcher), and the
             text-to-speech engines used for read-aloud (flutter_tts). -->
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="sms"/></intent>
        <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>
        <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
''';
      if (out.contains('</queries>')) {
        out = out.replaceFirst('</queries>', '$intents    </queries>');
      } else {
        out = _beforeLast(out, '</manifest>', '    <queries>\n$intents    </queries>\n');
      }
    }
    return out;
  });

  _patch('android/app/src/debug/AndroidManifest.xml', 'Debug-only plain HTTP for a local development server', (xml) {
    if (xml.contains('usesCleartextTraffic')) return xml;
    return _beforeLast(
      xml,
      '</manifest>',
      '    <!-- Debug builds only: lets the emulator reach a development server at\n'
          '         http://10.0.2.2. Release builds stay HTTPS-only. -->\n'
          '    <application android:usesCleartextTraffic="true"/>\n',
    );
  });

  // local_auth needs Android 7.0 (API 24) or newer.
  final kts = File('android/app/build.gradle.kts');
  if (kts.existsSync()) {
    _patch(kts.path, 'minSdk at least 24 (local_auth)', (g) {
      if (g.contains('maxOf(24')) return g;
      return g.replaceFirst(RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion'), 'minSdk = maxOf(24, flutter.minSdkVersion)');
    });
  } else {
    _patch('android/app/build.gradle', 'minSdk at least 24 (local_auth)', (g) {
      if (g.contains('Math.max(24')) return g;
      return g
          .replaceFirst(RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion'), 'minSdk = Math.max(24, flutter.minSdkVersion)')
          .replaceFirst(RegExp(r'minSdkVersion\s+flutter\.minSdkVersion'), 'minSdkVersion Math.max(24, flutter.minSdkVersion)');
    });
  }

  _patch('android/app/src/main/AndroidManifest.xml', 'App name shown under the icon', (xml) {
    return xml.replaceFirst(RegExp(r'android:label="aquaaware"'), 'android:label="$_appName"');
  });
  for (final density in const ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
    _copyAsset(
      'branding/android/mipmap-$density/ic_launcher.png',
      'android/app/src/main/res/mipmap-$density/ic_launcher.png',
      'Launcher icon ($density)',
    );
  }

  // local_auth shows the system biometric prompt, which needs a FragmentActivity.
  final activities = <File>[];
  for (final dir in ['android/app/src/main/kotlin', 'android/app/src/main/java']) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final e in d.listSync(recursive: true)) {
      if (e is File && (e.path.endsWith('MainActivity.kt') || e.path.endsWith('MainActivity.java'))) activities.add(e);
    }
  }
  if (activities.isEmpty) {
    stdout.writeln('  - MainActivity not found; make it extend FlutterFragmentActivity by hand.');
  }
  for (final f in activities) {
    _patch(f.path, 'MainActivity extends FlutterFragmentActivity (local_auth)', (src) {
      if (src.contains('FlutterFragmentActivity')) return src;
      return src
          .replaceAll('io.flutter.embedding.android.FlutterActivity', 'io.flutter.embedding.android.FlutterFragmentActivity')
          .replaceAll(RegExp(r':\s*FlutterActivity\(\)'), ': FlutterFragmentActivity()')
          .replaceAll(RegExp(r'extends\s+FlutterActivity\b'), 'extends FlutterFragmentActivity');
    });
  }
}

// ------------------------------------------------------------------- iOS ---

void _ios() {
  if (!Directory('ios').existsSync()) return;
  _section('iOS');
  _patch('ios/Runner/Info.plist', 'Camera, location and Face ID explanations; link schemes', (plist) {
    return _plistKeys(plist, {
      'NSCameraUsageDescription':
          _string('AquaAware uses the camera only to scan event check-in and reward QR codes.'),
      'NSLocationWhenInUseUsageDescription': _string(
          'AquaAware uses your location only when you ask: to find the nearest waste collectors and to confirm you are at the reward desk.'),
      'NSFaceIDUsageDescription': _string('Staff can use Face ID to unlock AquaAware quickly on their own device.'),
      'LSApplicationQueriesSchemes':
          '<array>\n\t\t<string>tel</string>\n\t\t<string>sms</string>\n\t\t<string>mailto</string>\n\t\t<string>https</string>\n\t</array>',
    });
  });
  _patch('ios/Runner/Info.plist', 'App name shown under the icon', (plist) {
    return plist.replaceFirstMapped(
      RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)Aquaaware(</string>)'),
      (m) => '${m[1]}$_appName${m[2]}',
    );
  });
}

// ----------------------------------------------------------------- macOS ---

void _macos() {
  if (!Directory('macos').existsSync()) return;
  _section('macOS');
  _patch('macos/Runner/Info.plist', 'Camera and location explanations', (plist) {
    return _plistKeys(plist, {
      'NSCameraUsageDescription':
          _string('AquaAware uses the camera only to scan event check-in and reward QR codes.'),
      'NSLocationUsageDescription':
          _string('AquaAware uses your location only when you ask, to find the nearest waste collectors.'),
      'NSLocationWhenInUseUsageDescription':
          _string('AquaAware uses your location only when you ask, to find the nearest waste collectors.'),
    });
  });

  // The macOS sandbox blocks everything that is not declared here.
  const entitlements = {
    'com.apple.security.network.client': '<true/>', // talk to the API and map tiles
    'com.apple.security.device.camera': '<true/>', // QR scanning
    'com.apple.security.personal-information.location': '<true/>',
    'com.apple.security.files.user-selected.read-only': '<true/>', // educator file picker
  };
  for (final file in ['macos/Runner/DebugProfile.entitlements', 'macos/Runner/Release.entitlements']) {
    _patch(file, 'Sandbox entitlements in ${file.split('/').last}', (plist) => _plistKeys(plist, entitlements));
  }
  _notes.add(
    'macOS: to keep encryption keys in the Keychain between launches, open macos/Runner.xcworkspace in Xcode, '
    'choose a signing team and add the "Keychain Sharing" capability. Without it AquaAware still runs, '
    'but keeps data in memory only (the Security Center says so).',
  );
}

// ------------------------------------------------------------------- Web ---

const _appName = 'AquaAware';
const _tagline = 'Water and waste awareness for Pondicherry schools: learn, act and earn rewards.';
const _themeHex = '#1C6E8C'; // AqColors.tide
const _backgroundHex = '#F3F6F6'; // AqColors.seaSalt

/// Shown while the Flutter engine downloads; removed by flutter_bootstrap.js
/// once the app is running. Honours dark mode and reduced motion.
const _loadingScreen = '''
  <div id="aq-loading" role="status" aria-live="polite">
    <style>
      #aq-loading { position: fixed; inset: 0; z-index: 10; display: flex; flex-direction: column;
        align-items: center; justify-content: center; gap: 16px; background: #F3F6F6; color: #0F2A36;
        font: 600 18px/1.4 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
      #aq-loading img { width: 96px; height: 96px; border-radius: 22px; animation: aq-bob 2.4s ease-in-out infinite; }
      #aq-loading small { font-weight: 400; font-size: 14px; opacity: .8; }
      @keyframes aq-bob { 50% { transform: translateY(-6px); } }
      @media (prefers-reduced-motion: reduce) { #aq-loading img { animation: none; } }
      @media (prefers-color-scheme: dark) { #aq-loading { background: #08171E; color: #E3EEF1; } }
    </style>
    <img src="icons/Icon-192.png" alt="">
    <div id="aq-loading-text">AquaAware is loading…</div>
    <small>Water and waste awareness for Pondicherry schools</small>
    <noscript>AquaAware needs JavaScript. Please turn it on and reload.</noscript>
  </div>
''';

/// Flutter's documented custom bootstrap: load the engine, run the app, then
/// remove the loading screen. On failure, say so instead of a blank page.
const _bootstrapJs = r'''
{{flutter_js}}
{{flutter_build_config}}

(function () {
  var loading = document.getElementById('aq-loading');
  var text = document.getElementById('aq-loading-text');
  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        var appRunner = await engineInitializer.initializeEngine();
        await appRunner.runApp();
        if (loading) loading.remove();
      } catch (e) {
        if (text) text.textContent = 'AquaAware could not start. Please reload the page.';
        console.error(e);
      }
    },
  });
})();
''';

Map<String, dynamic>? _jsonObject(String text) {
  try {
    final v = jsonDecode(text);
    return v is Map<String, dynamic> ? v : null;
  } on FormatException {
    return null;
  }
}

void _web() {
  if (!Directory('web').existsSync()) return;
  _section('Web');

  _patch('web/index.html', 'Title, description, theme colour and loading screen', (html) {
    var out = html
        .replaceFirst(RegExp(r'<title>[^<]*</title>'), '<title>$_appName</title>')
        .replaceFirst(RegExp(r'<meta name="description" content="[^"]*">'), '<meta name="description" content="$_tagline">')
        .replaceFirst(
          RegExp(r'<meta name="apple-mobile-web-app-title" content="[^"]*">'),
          '<meta name="apple-mobile-web-app-title" content="$_appName">',
        );
    if (!out.contains('name="theme-color"')) {
      out = out.replaceFirst('<meta charset="UTF-8">', '<meta charset="UTF-8">\n  <meta name="theme-color" content="$_themeHex">');
    }
    if (!out.contains('id="aq-loading"')) {
      out = out.replaceFirst('<body>', '<body>\n$_loadingScreen');
    }
    return out;
  });

  _writeIfDifferent('web/flutter_bootstrap.js', _bootstrapJs, 'Loader that removes the loading screen when the app starts');

  _patch('web/manifest.json', 'Installable app name, description and colours', (text) {
    final m = _jsonObject(text);
    if (m == null) return text;
    m
      ..['name'] = _appName
      ..['short_name'] = _appName
      ..['description'] = _tagline
      ..['background_color'] = _backgroundHex
      ..['theme_color'] = _themeHex;
    return '${const JsonEncoder.withIndent('    ').convert(m)}\n';
  });

  _copyAsset('branding/web/favicon.png', 'web/favicon.png', 'Favicon');
  for (final name in const ['Icon-192.png', 'Icon-512.png', 'Icon-maskable-192.png', 'Icon-maskable-512.png']) {
    _copyAsset('branding/web/icons/$name', 'web/icons/$name', 'Web app icon $name');
  }
}

// --------------------------------------------------------- desktop titles ---

void _desktopTitles() {
  if (Directory('windows').existsSync()) {
    _section('Windows');
    _patch('windows/runner/main.cpp', 'Window title', (src) => src.replaceAll('L"aquaaware"', 'L"$_appName"'));
  }
  if (Directory('linux').existsSync()) {
    _section('Linux');
    _patch('linux/runner/my_application.cc', 'Window title', (src) => src.replaceAll('"aquaaware"', '"$_appName"'));
  }
}

// ---------------------------------------------------------- file helpers ---

/// Writes [content] to [path] unless it already holds exactly that.
void _writeIfDifferent(String path, String content, String what) {
  final f = File(path);
  if (!f.parent.existsSync()) {
    stdout.writeln('  - $what: ${f.parent.path} not found (platform not created?)');
    return;
  }
  if (f.existsSync() && f.readAsStringSync() == content) {
    stdout.writeln('  [ok]   $what (already done)');
    return;
  }
  f.writeAsStringSync(content);
  _changed++;
  stdout.writeln('  [done] $what');
}

/// Copies a file from branding/ over the generated one when they differ.
void _copyAsset(String from, String to, String what) {
  final src = File(from);
  if (!src.existsSync()) {
    stdout.writeln('  - $what: $from is missing');
    return;
  }
  final dst = File(to);
  if (!dst.parent.existsSync()) {
    stdout.writeln('  - $what: ${dst.parent.path} not found (platform not created?)');
    return;
  }
  final bytes = src.readAsBytesSync();
  if (dst.existsSync() && _sameBytes(dst.readAsBytesSync(), bytes)) {
    stdout.writeln('  [ok]   $what (already done)');
    return;
  }
  dst.writeAsBytesSync(bytes);
  _changed++;
  stdout.writeln('  [done] $what');
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ------------------------------------------------------------ build tools ---

void _toolChecks() {
  if (Platform.isWindows && Directory('windows').existsSync()) {
    final r = Process.runSync('where', ['nuget'], runInShell: true);
    if (r.exitCode != 0) {
      _notes.add('Windows: read-aloud (flutter_tts) needs NuGet to build. Install it with:  winget install Microsoft.NuGet');
    }
  }
  if (Platform.isLinux && Directory('linux').existsSync()) {
    var hasSecret = false;
    try {
      hasSecret = Process.runSync('pkg-config', ['--exists', 'libsecret-1']).exitCode == 0;
    } catch (_) {}
    if (!hasSecret) {
      _notes.add('Linux: secure storage needs libsecret. Install it with:  sudo apt install libsecret-1-dev libjsoncpp-dev');
    }
  }
}
