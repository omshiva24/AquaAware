// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds light, dark and high-contrast themes from the AquaAware tokens.
abstract final class AqTheme {
  static const fontFamily = 'AtkinsonNext';

  static ThemeData light({bool highContrast = false}) =>
      _build(_lightScheme(highContrast), highContrast);

  static ThemeData dark({bool highContrast = false}) =>
      _build(_darkScheme(highContrast), highContrast);

  static ColorScheme _lightScheme(bool hc) {
    final base = ColorScheme.fromSeed(
      seedColor: AqColors.tide,
      brightness: Brightness.light,
    );
    return base.copyWith(
      primary: hc ? AqColors.tideDeep : AqColors.tide,
      onPrimary: Colors.white,
      primaryContainer: AqColors.foam,
      onPrimaryContainer: AqColors.ink,
      secondary: AqColors.ochre,
      onSecondary: AqColors.ink,
      secondaryContainer: AqColors.ochreWash,
      onSecondaryContainer: AqColors.ochreInk,
      tertiary: AqColors.mangrove,
      onTertiary: Colors.white,
      tertiaryContainer: AqColors.mangroveWash,
      onTertiaryContainer: const Color(0xFF0E3B27),
      error: AqColors.brick,
      onError: Colors.white,
      errorContainer: AqColors.brickWash,
      onErrorContainer: const Color(0xFF5C0E0A),
      surface: AqColors.surface,
      onSurface: hc ? Colors.black : AqColors.ink,
      onSurfaceVariant: hc ? AqColors.ink : AqColors.inkSoft,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF7FAFA),
      surfaceContainer: AqColors.seaSalt,
      surfaceContainerHigh: const Color(0xFFEAF0F1),
      surfaceContainerHighest: const Color(0xFFE1E9EB),
      outline: hc ? AqColors.ink : const Color(0xFF6E828B),
      outlineVariant: hc ? AqColors.inkSoft : AqColors.line,
      inverseSurface: AqColors.ink,
      onInverseSurface: Colors.white,
      inversePrimary: AqColors.shallows,
    );
  }

  static ColorScheme _darkScheme(bool hc) {
    final base = ColorScheme.fromSeed(
      seedColor: AqColors.tide,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      primary: hc ? const Color(0xFFA8E6F2) : AqColors.nightTide,
      onPrimary: const Color(0xFF052430),
      primaryContainer: const Color(0xFF134456),
      onPrimaryContainer: const Color(0xFFD4F1F7),
      secondary: AqColors.nightOchre,
      onSecondary: const Color(0xFF2B1D00),
      secondaryContainer: const Color(0xFF4A3608),
      onSecondaryContainer: const Color(0xFFFFE3A6),
      tertiary: AqColors.nightMangrove,
      onTertiary: const Color(0xFF00381F),
      tertiaryContainer: const Color(0xFF14432F),
      onTertiaryContainer: const Color(0xFFC6F0D9),
      error: AqColors.nightBrick,
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF5C1712),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: AqColors.nightSurface,
      onSurface: hc ? Colors.white : AqColors.nightText,
      onSurfaceVariant: hc ? AqColors.nightText : AqColors.nightTextSoft,
      surfaceContainerLowest: AqColors.nightSea,
      surfaceContainerLow: const Color(0xFF0C1E26),
      surfaceContainer: AqColors.nightSurface,
      surfaceContainerHigh: AqColors.nightRaised,
      surfaceContainerHighest: const Color(0xFF1B3946),
      outline: hc ? AqColors.nightText : const Color(0xFF7F99A3),
      outlineVariant: hc ? AqColors.nightTextSoft : AqColors.nightLine,
      inverseSurface: AqColors.nightText,
      onInverseSurface: AqColors.nightSea,
      inversePrimary: AqColors.tide,
    );
  }

  static TextTheme _textTheme(ColorScheme s) {
    final ink = s.onSurface;
    final soft = s.onSurfaceVariant;
    return TextTheme(
      displayLarge: TextStyle(fontSize: 56, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -1.6, color: ink),
      displayMedium: TextStyle(fontSize: 44, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: ink),
      displaySmall: TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: ink),
      headlineLarge: TextStyle(fontSize: 32, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: ink),
      headlineMedium: TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: ink),
      headlineSmall: TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: ink),
      titleLarge: TextStyle(fontSize: 20, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.1, color: ink),
      titleMedium: TextStyle(fontSize: 17, height: 1.3, fontWeight: FontWeight.w700, color: ink),
      titleSmall: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: TextStyle(fontSize: 17, height: 1.5, fontWeight: FontWeight.w400, color: ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w400, color: ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w400, color: soft),
      labelLarge: TextStyle(fontSize: 15, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 0.1, color: ink),
      labelMedium: TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w500, color: ink),
      labelSmall: TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w500, letterSpacing: 0.2, color: soft),
    );
  }

  static ThemeData _build(ColorScheme s, bool hc) {
    final text = _textTheme(s);
    final isDark = s.brightness == Brightness.dark;
    final borderWidth = hc ? 2.0 : 1.0;

    OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AqRadius.control),
          borderSide: BorderSide(color: c, width: w),
        );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AqRadius.control),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: s,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: isDark ? AqColors.nightSea : AqColors.seaSalt,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarThemeData(
        backgroundColor: isDark ? AqColors.nightSea : AqColors.seaSalt,
        foregroundColor: s.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: s.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AqRadius.card),
          side: BorderSide(color: s.outlineVariant, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isDark ? AqColors.nightRaised : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder(s.outline, borderWidth),
        enabledBorder: inputBorder(hc ? s.outline : s.outlineVariant, borderWidth),
        focusedBorder: inputBorder(s.primary, 2),
        errorBorder: inputBorder(s.error, borderWidth),
        focusedErrorBorder: inputBorder(s.error, 2),
        labelStyle: text.bodyMedium?.copyWith(color: s.onSurfaceVariant),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: s.primary, fontWeight: FontWeight.w700),
        hintStyle: text.bodyMedium?.copyWith(color: s.onSurfaceVariant),
        prefixIconColor: s.onSurfaceVariant,
        suffixIconColor: s.onSurfaceVariant,
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape,
          side: BorderSide(color: s.outline, width: borderWidth),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: isDark ? AqColors.nightSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: s.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? s.onSurface : s.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? AqColors.nightSurface : Colors.white,
        indicatorColor: s.primaryContainer,
        selectedLabelTextStyle: text.labelLarge,
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: s.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: s.outlineVariant, width: borderWidth),
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: s.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: s.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AqRadius.control)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AqRadius.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AqRadius.sheet)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: s.onSurfaceVariant,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AqRadius.control)),
      ),
      dividerTheme: DividerThemeData(color: s.outlineVariant, space: 1, thickness: 1),
      tabBarTheme: TabBarThemeData(
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelMedium,
        labelColor: s.onSurface,
        unselectedLabelColor: s.onSurfaceVariant,
        indicatorColor: s.primary,
        dividerColor: s.outlineVariant,
      ),
    );
  }
}
