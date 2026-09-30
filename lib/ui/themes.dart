// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Fallback seed when dynamic colors are unavailable.
const _fallbackSeed = Colors.blue;

/// Built-in color scheme seed colors (key → Color).
const Map<String, Color> colorSchemes = {
  'blue': Color(0xFF1565C0),
  'green': Color(0xFF2E7D32),
  'purple': Color(0xFF7B1FA2),
  'orange': Color(0xFFE65100),
  'teal': Color(0xFF00796B),
  'pink': Color(0xFFC2185B),
};

/// Ordered list of all color scheme keys including 'system'.
const List<String> colorSchemeKeys = ['system', 'blue', 'green', 'purple', 'orange', 'teal', 'pink'];

/// Returns a [ColorScheme] for the given key and brightness.
/// 'system' falls back to the default seed; presets use their seed color.
ColorScheme buildColorScheme(String key, Brightness brightness) {
  final seed = colorSchemes[key];
  return ColorScheme.fromSeed(
    seedColor: seed ?? _fallbackSeed,
    brightness: brightness,
  );
}

ThemeData _buildLightTheme([ColorScheme? cs, bool useSystemFont = false]) =>
    _buildTheme(cs ?? ColorScheme.fromSeed(seedColor: _fallbackSeed, brightness: Brightness.light), useSystemFont);
ThemeData _buildDarkTheme([ColorScheme? cs, bool useSystemFont = false]) =>
    _buildTheme(cs ?? ColorScheme.fromSeed(seedColor: _fallbackSeed, brightness: Brightness.dark), useSystemFont);

ThemeData _buildTheme(ColorScheme colorScheme, bool useSystemFont) {
  final isDark = colorScheme.brightness == Brightness.dark;
  final typography = Typography.material2021(platform: TargetPlatform.android);
  final textTheme = useSystemFont
      ? (isDark ? typography.white : typography.black)
      : (isDark ? typography.white : typography.black).apply(fontFamily: 'MontserratRegular');

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surfaceDim, // 页面背景用 surfaceDim（比 surface 稍暗），和卡片拉开色差
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
      elevation: 0, // 阴影高度，0 为无阴影
      color: colorScheme.surfaceContainerHighest, // 卡片背景色，和 scaffold 的 surface 有明显色差
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // 圆角矩形，12px 圆角
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // 卡片外边距，左右各 16，上下各 4
      clipBehavior: Clip.antiAlias, // 圆角裁剪，让 hover/ripple 不溢出
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
      backgroundColor: colorScheme.surfaceContainerHigh, // 导航栏背景，比页面 surfaceDim 稍亮，形成层次
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
  /// [colorSchemeKey] selects a preset seed; 'system' or null uses default.
  factory Themes.lightTheme([ColorScheme? cs, bool useSystemFont = false, String? colorSchemeKey]) {
    final effectiveCs = cs ?? (colorSchemeKey != null ? buildColorScheme(colorSchemeKey, Brightness.light) : null);
    return Themes(themeData: _buildLightTheme(effectiveCs, useSystemFont));
  }

  factory Themes.darkTheme([ColorScheme? cs, bool useSystemFont = false, String? colorSchemeKey]) {
    final effectiveCs = cs ?? (colorSchemeKey != null ? buildColorScheme(colorSchemeKey, Brightness.dark) : null);
    return Themes(themeData: _buildDarkTheme(effectiveCs, useSystemFont));
  }
}
