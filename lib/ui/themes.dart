// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

final ThemeData _lightTheme = _buildLightTheme();
final ThemeData _darkTheme = _buildDarkTheme();

ThemeData _buildLightTheme() {
  const colorScheme = ColorScheme.light(
    primary: Color(0xFFFF9800),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE0B2),
    onPrimaryContainer: Color(0xFF3E2700),
    secondary: Color(0xFFFB8C00),
    onSecondary: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFBFE),
    onSurface: Color(0xFF1C1B1F),
    surfaceContainerHighest: Color(0xFFF5F5F5),
    onSurfaceVariant: Color(0xFF49454F),
    outline: Color(0xFFE0E0E0),
    outlineVariant: Color(0xFFCAC4D0),
    error: Color(0xFFD32F2F),
    onError: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7F2FA),
    surfaceContainerHigh: Color(0xFFECE6F0),
  );

  final textTheme =
      Typography.material2021(platform: TargetPlatform.android).black.apply(fontFamily: 'MontserratRegular');

  return ThemeData.light(useMaterial3: true).copyWith(
    colorScheme: colorScheme,
    brightness: Brightness.light,
    scaffoldBackgroundColor: colorScheme.surface,
    dividerColor: colorScheme.outline,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    iconTheme: IconThemeData(color: colorScheme.onSurface),
    primaryIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
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
      color: colorScheme.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: colorScheme.surface,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: textTheme.labelLarge,
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
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return colorScheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primaryContainer;
        return colorScheme.surfaceContainerHighest;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: colorScheme.surfaceContainerHighest,
      thumbColor: colorScheme.primary,
      valueIndicatorColor: colorScheme.primary,
      trackHeight: 2.0,
      thumbShape: const RoundSliderThumbShape(
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
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colorScheme.onPrimaryContainer);
        }
        return IconThemeData(color: colorScheme.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return textTheme.labelMedium?.copyWith(color: colorScheme.onSurface);
        }
        return textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant);
      }),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: colorScheme.onSurface),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

ThemeData _buildDarkTheme() {
  const colorScheme = ColorScheme.dark(
    primary: Color(0xFFFFCC80),
    onPrimary: Color(0xFF3E2700),
    primaryContainer: Color(0xFF5D3F00),
    onPrimaryContainer: Color(0xFFFFE0B2),
    secondary: Color(0xFFFFCC80),
    onSecondary: Color(0xFF3E2700),
    surface: Color(0xFF1C1B1F),
    onSurface: Color(0xFFE6E1E5),
    surfaceContainerHighest: Color(0xFF2D2D2D),
    onSurfaceVariant: Color(0xFFCAC4D0),
    outline: Color(0xFF444444),
    outlineVariant: Color(0xFF49454F),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    surfaceContainerLow: Color(0xFF25232A),
    surfaceContainerHigh: Color(0xFF36343B),
  );

  final textTheme =
      Typography.material2021(platform: TargetPlatform.android).white.apply(fontFamily: 'MontserratRegular');

  return ThemeData.dark(useMaterial3: true).copyWith(
    colorScheme: colorScheme,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: colorScheme.surface,
    dividerColor: colorScheme.outline,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    iconTheme: IconThemeData(color: colorScheme.onSurface),
    primaryIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
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
      color: colorScheme.surfaceContainerHighest,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: colorScheme.surfaceContainerHighest,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      backgroundColor: colorScheme.surfaceContainerHighest,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: textTheme.labelLarge,
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
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return colorScheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primaryContainer;
        return colorScheme.surfaceContainerHighest;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: colorScheme.surfaceContainerHighest,
      thumbColor: colorScheme.primary,
      valueIndicatorColor: colorScheme.primary,
      trackHeight: 2.0,
      thumbShape: const RoundSliderThumbShape(
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
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colorScheme.onPrimaryContainer);
        }
        return IconThemeData(color: colorScheme.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return textTheme.labelMedium?.copyWith(color: colorScheme.onSurface);
        }
        return textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant);
      }),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outline),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

class Themes {
  final ThemeData themeData;

  Themes({required this.themeData});

  factory Themes.lightTheme() {
    return Themes(themeData: _lightTheme);
  }

  factory Themes.darkTheme() {
    return Themes(themeData: _darkTheme);
  }
}
