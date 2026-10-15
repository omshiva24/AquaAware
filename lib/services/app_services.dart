// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../core/net/sync_service.dart';
import '../core/platform/capabilities.dart';
import '../core/platform/device_context.dart';
import '../core/platform/speech_service.dart';
import '../core/security/secure_vault.dart';
import '../core/theme/tokens.dart';
import '../data/app_store.dart';
import 'auth_service.dart';
import 'settings_controller.dart';

/// Every long-lived service, created once at start-up.
class AppServices {
  AppServices._({
    required this.vault,
    required this.store,
    required this.auth,
    required this.settings,
    required this.device,
    required this.sync,
    required this.speech,
  });

  final SecureVault vault;
  final AppStore store;
  final AuthService auth;
  final SettingsController settings;
  final DeviceContext device;
  final SyncService sync;
  final SpeechService speech;

  /// [startSensors] is false in widget tests, where battery and network
  /// plugins have no platform side to talk to.
  static Future<AppServices> bootstrap({bool startSensors = true}) async {
    final vault = await SecureVault.open();
    final sync = SyncService(vault: vault);
    final store = AppStore(vault, sync);
    final settings = SettingsController(vault);
    final device = DeviceContext();
    await Future.wait([store.load(), settings.load(), sync.load()]);
    // Announcements from other devices flow into the store (Q2 relay).
    sync.onRemote = store.mergeRemote;
    final auth = AuthService(vault, store, sync);
    await auth.restore();
    if (startSensors) unawaited(device.start());
    // Retry the outbox whenever connectivity changes (Q5).
    device.addListener(() {
      if (!device.isOffline) unawaited(sync.flush());
    });
    return AppServices._(
      vault: vault,
      store: store,
      auth: auth,
      settings: settings,
      device: device,
      sync: sync,
      speech: SpeechService(),
    );
  }
}

/// Makes [AppServices] reachable from any widget without a package.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => !identical(services, oldWidget.services);
}

extension AppContext on BuildContext {
  AppServices get services => AppScope.of(this);

  /// True when motion should be minimised: the system setting, the in-app
  /// setting, or low battery / battery saver (Q2).
  bool get reduceMotion {
    final s = AppScope.of(this);
    return MediaQuery.of(this).disableAnimations || s.settings.reduceMotion || s.device.shouldConserveEnergy;
  }

  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;

  /// Speaks a status change to screen readers (TalkBack, VoiceOver, NVDA…).
  void announce(String message) {
    unawaited(SemanticsService.sendAnnouncement(View.of(this), message, Directionality.of(this)));
  }

  void toast(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: error ? AqColors.nightBrick : AqColors.shallows,
              semanticLabel: error ? 'Error' : 'Done',
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ));
    // SnackBars are live regions on Android and the web; VoiceOver needs a nudge.
    if (Caps.isIOS || defaultTargetPlatform == TargetPlatform.macOS) announce(message);
  }
}
