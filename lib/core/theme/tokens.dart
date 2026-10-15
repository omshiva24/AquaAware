// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'package:flutter/material.dart';

/// Design tokens for AquaAware.
///
/// The palette comes from Pondicherry itself: the Bay of Bengal (ink, tide,
/// shallows), sea-salt air (background), the ochre walls of White Town
/// (points and rewards) and the mangroves of Ariyankuppam (NGO / success).
///
/// Every text/background pairing used in the UI meets WCAG 2.2 AA (4.5:1).
abstract final class AqColors {
  // Light
  static const ink = Color(0xFF0F2A36); // primary text, deep water
  static const inkSoft = Color(0xFF4A5F69); // secondary text (6.6:1 on white)
  static const tide = Color(0xFF1C6E8C); // brand primary (5.6:1 with white)
  static const tideDeep = Color(0xFF124B60);
  static const shallows = Color(0xFF8FD3E0);
  static const foam = Color(0xFFE2F2F5);
  static const seaSalt = Color(0xFFF3F6F6);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFD5E0E3);

  static const ochre = Color(0xFFE0A526); // fills only — never small text on white
  static const ochreInk = Color(0xFF7A4E00); // ochre-family text (7.0:1 on white)
  static const ochreWash = Color(0xFFFBF0D6);

  static const mangrove = Color(0xFF2F7D5B); // 5.0:1 with white
  static const mangroveWash = Color(0xFFDDF0E6);

  static const brick = Color(0xFFB3261E);
  static const brickWash = Color(0xFFFBE4E2);

  // Dark
  static const nightSea = Color(0xFF08171E);
  static const nightSurface = Color(0xFF0F232C);
  static const nightRaised = Color(0xFF15303B);
  static const nightLine = Color(0xFF26444F);
  static const nightText = Color(0xFFE3EEF1);
  static const nightTextSoft = Color(0xFFA7BCC4);
  static const nightTide = Color(0xFF6CC6DA);
  static const nightOchre = Color(0xFFF2BE4B);
  static const nightMangrove = Color(0xFF6CC79B);
  static const nightBrick = Color(0xFFFFB4AB);
}

/// Spacing scale (4-pt base).
abstract final class AqSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const gutter = 16.0;
  static const maxContent = 880.0;
}

/// Radius hierarchy: the bigger and more important a surface, the softer it is.
abstract final class AqRadius {
  static const hero = 28.0; // reservoir, login sheet
  static const sheet = 24.0; // bottom sheets, dialogs
  static const card = 16.0; // grouped sections
  static const control = 12.0; // inputs, buttons
  static const pill = 999.0; // chips, badges
}

/// Motion durations. Everything collapses to zero when reduced motion is on.
abstract final class AqMotion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 520);
  static const wavePeriod = Duration(seconds: 7);
  static const emphasized = Cubic(0.2, 0, 0, 1);
}

/// Role accents used on badges and the navigation indicator.
enum RoleAccent { student, educator, ngo, manager }
