// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'package:flutter/material.dart';

import '../core/security/secure_vault.dart';

enum QuizTimerMode {
  standard(30, 'Standard (30 s)'),
  extended(60, 'Extended (60 s)'),
  off(0, 'No timer');

  const QuizTimerMode(this.seconds, this.label);
  final int seconds;
  final String label;
}

/// Accessibility and comfort preferences, saved per device.
class SettingsController extends ChangeNotifier {
  SettingsController(this._vault);

  final SecureVault _vault;
  static const _slot = 'settings';

  ThemeMode themeMode = ThemeMode.system;
  bool highContrast = false;

  /// Multiplies the system text size (1.0 = system default).
  double textScale = 1.0;
  bool reduceMotion = false;
  QuizTimerMode quizTimer = QuizTimerMode.standard;
  double speechRate = 0.5;

  /// Q1 — always request low-resolution images.
  bool dataSaver = false;

  /// Q2 — hold non-urgent notices during class hours.
  bool quietHours = true;

  Future<void> load() async {
    final raw = await _vault.readJson(_slot);
    if (raw is! Map) return;
    final j = raw.cast<String, Object?>();
    themeMode = ThemeMode.values.asNameMap()[j['themeMode']] ?? ThemeMode.system;
    highContrast = (j['highContrast'] as bool?) ?? false;
    textScale = ((j['textScale'] as num?) ?? 1.0).toDouble().clamp(0.85, 1.6);
    reduceMotion = (j['reduceMotion'] as bool?) ?? false;
    quizTimer = QuizTimerMode.values.asNameMap()[j['quizTimer']] ?? QuizTimerMode.standard;
    speechRate = ((j['speechRate'] as num?) ?? 0.5).toDouble().clamp(0.3, 0.7);
    dataSaver = (j['dataSaver'] as bool?) ?? false;
    quietHours = (j['quietHours'] as bool?) ?? true;
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    await _vault.writeJson(_slot, {
      'themeMode': themeMode.name,
      'highContrast': highContrast,
      'textScale': textScale,
      'reduceMotion': reduceMotion,
      'quizTimer': quizTimer.name,
      'speechRate': speechRate,
      'dataSaver': dataSaver,
      'quietHours': quietHours,
    });
  }

  Future<void> setThemeMode(ThemeMode v) { themeMode = v; return _save(); }
  Future<void> setHighContrast(bool v) { highContrast = v; return _save(); }
  Future<void> setTextScale(double v) { textScale = v.clamp(0.85, 1.6); return _save(); }
  Future<void> setReduceMotion(bool v) { reduceMotion = v; return _save(); }
  Future<void> setQuizTimer(QuizTimerMode v) { quizTimer = v; return _save(); }
  Future<void> setSpeechRate(double v) { speechRate = v.clamp(0.3, 0.7); return _save(); }
  Future<void> setDataSaver(bool v) { dataSaver = v; return _save(); }
  Future<void> setQuietHours(bool v) { quietHours = v; return _save(); }
}
