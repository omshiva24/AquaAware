// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'capabilities.dart';

enum NetworkKind { wifi, cellular, wired, offline, unknown }

/// Q1, Q2, Q10 — context awareness.
///
/// * Q1 adaptive quality: on cellular data (or data-saver) images are
///   requested at lower resolution.
/// * Q2 battery awareness: below 20% (not charging) or in battery-saver mode
///   decorative animation pauses and quizzes auto-save after every answer.
/// * Q10 low-end devices: small Android screens get lighter imagery.
class DeviceContext extends ChangeNotifier {
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<BatteryState>? _batterySub;
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  Timer? _poll;

  int? batteryLevel;
  bool batterySaver = false;
  bool charging = false;
  NetworkKind network = NetworkKind.unknown;
  bool lowEndDevice = false;

  bool get isLowBattery => batteryLevel != null && batteryLevel! < 20 && !charging;
  bool get isOffline => network == NetworkKind.offline;
  bool get isCellular => network == NetworkKind.cellular;
  bool get shouldConserveEnergy => isLowBattery || batterySaver;

  Future<void> start() async {
    await Future.wait([_refreshBattery(), _refreshNetwork()]);
    try {
      _batterySub = _battery.onBatteryStateChanged.listen(
        (state) {
          charging = state == BatteryState.charging || state == BatteryState.full;
          unawaited(_refreshBattery());
        },
        onError: (Object _) {},
      );
    } catch (_) {}
    try {
      _netSub = _connectivity.onConnectivityChanged.listen(_applyNetwork, onError: (Object _) {});
    } catch (_) {}
    _poll = Timer.periodic(const Duration(minutes: 2), (_) => unawaited(_refreshBattery()));
  }

  /// Called from the app root whenever the window size changes (Q10).
  void updateScreen(Size logical) {
    final low = Caps.isAndroid && logical.shortestSide > 0 && logical.shortestSide < 360;
    if (low != lowEndDevice) {
      lowEndDevice = low;
      notifyListeners();
    }
  }

  Future<void> _refreshBattery() async {
    try {
      final level = await _battery.batteryLevel;
      bool saver = false;
      try {
        saver = await _battery.isInBatterySaveMode;
      } catch (_) {}
      if (level != batteryLevel || saver != batterySaver) {
        batteryLevel = level;
        batterySaver = saver;
        notifyListeners();
      }
    } catch (_) {
      // Desktops without a battery, or unsupported platforms: stay unknown.
    }
  }

  Future<void> _refreshNetwork() async {
    try {
      _applyNetwork(await _connectivity.checkConnectivity());
    } catch (_) {}
  }

  void _applyNetwork(List<ConnectivityResult> results) {
    NetworkKind next;
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      next = NetworkKind.offline;
    } else if (results.contains(ConnectivityResult.ethernet)) {
      next = NetworkKind.wired;
    } else if (results.contains(ConnectivityResult.wifi)) {
      next = NetworkKind.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      next = NetworkKind.cellular;
    } else {
      next = NetworkKind.unknown;
    }
    if (next != network) {
      network = next;
      notifyListeners();
    }
  }

  String describeNetwork() => switch (network) {
        NetworkKind.wifi => 'Wi-Fi',
        NetworkKind.cellular => 'Mobile data',
        NetworkKind.wired => 'Wired',
        NetworkKind.offline => 'Offline',
        NetworkKind.unknown => 'Unknown',
      };

  @override
  void dispose() {
    unawaited(_batterySub?.cancel());
    unawaited(_netSub?.cancel());
    _poll?.cancel();
    super.dispose();
  }
}

class WaterMeterReading {
  const WaterMeterReading({required this.usedLitres, required this.targetLitres, required this.at});
  final int usedLitres;
  final int targetLitres;
  final DateTime at;
  bool get underTarget => usedLitres <= targetLitres;
  double get fraction => (usedLitres / targetLitres).clamp(0.0, 1.4);
}

/// Q12 — IoT water meter for the school tank.
///
/// Until a real meter (e.g. an ESP32 + flow sensor posting to the API) is
/// connected, this simulates a school-day usage curve that is stable for a
/// given date, so every role sees the same reading.
abstract final class WaterMeter {
  static const int targetLitres = 300;

  static WaterMeterReading read(DateTime now) {
    final seed = now.year * 372 + now.month * 31 + now.day;
    final dayFactor = 0.82 + (seed % 23) / 100; // 0.82 – 1.04 of target
    final minutes = now.hour * 60 + now.minute;
    double progress;
    if (minutes < 7 * 60) {
      progress = 0.03;
    } else if (minutes > 17 * 60) {
      progress = 1.0;
    } else {
      progress = 0.03 + 0.97 * ((minutes - 420) / 600);
    }
    final weekend = now.weekday >= DateTime.saturday;
    final used = (targetLitres * dayFactor * progress * (weekend ? 0.25 : 1.0)).round();
    return WaterMeterReading(usedLitres: used, targetLitres: targetLitres, at: now);
  }
}
