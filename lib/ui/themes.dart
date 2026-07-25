// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Fallback seed when dynamic colors are unavailable.
const _fallbackSeed = Colors.blue;

ThemeData _buildLightTheme([ColorScheme? cs, bool useSystemFont = false]) =>
    _buildTheme(cs ?? ColorScheme.fromSeed(seedColor: _fallbackSeed, brightness: Brightness.light), useSystemFont);
ThemeData _buildDarkTheme([ColorScheme? cs, bool useSystemFont = false]) =>
    _buildTheme(cs ?? ColorScheme.fromSeed(seedColor: _fallbackSeed, brightness: Brightness.dark), useSystemFont);

ThemeData _buildTheme(ColorScheme colorScheme, bool useSystemFont) {
  final isDark = colorScheme.brightness == Brightness.dark;
  final typography = Typography.material2021(platform: TargetPlatform.android);
  final textTheme =
      useSystemFont ? (isDark ? typography.white : typography.black) : (isDark ? typography.white : typography.black).apply(fontFamily: 'MontserratRegular');

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 3,
      surfaceTintColor: Colors.transparent,
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: colorScheme.surface,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 2.0,
      thumbShape: RoundSliderThumbShape(
        enabledThumbRadius: 6.0,
        disabledThumbRadius: 6.0,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: colorScheme.primary,
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.secondaryContainer,
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.secondaryContainer,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline,
    ),
  );
}

class Themes {
  final ThemeData themeData;

  Themes({required this.themeData});

  /// Build with optional dynamic color scheme override.
  factory Themes.lightTheme([ColorScheme? cs, bool useSystemFont = false]) =>
      Themes(themeData: cs != null ? _buildLightTheme(cs, useSystemFont) : _buildLightTheme(null, useSystemFont));

  factory Themes.darkTheme([ColorScheme? cs, bool useSystemFont = false]) =>
      Themes(themeData: cs != null ? _buildDarkTheme(cs, useSystemFont) : _buildDarkTheme(null, useSystemFont));
}
