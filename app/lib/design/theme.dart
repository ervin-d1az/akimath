import 'package:flutter/material.dart';

import 'tokens/tokens.dart';

/// The app's single theme.
///
/// There is no dark theme and no second palette. The visual system is fixed:
/// cream canvas, ink outlines, hard shadows. Material's own elevation shadows
/// are switched off everywhere, because a blurred shadow is a brand defect.
abstract final class AkiMathTheme {
  static ThemeData build() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: BrandColors.green,
      onPrimary: BrandColors.ink,
      secondary: BrandColors.pink,
      onSecondary: BrandColors.surface,
      error: BrandColors.coral,
      onError: BrandColors.ink,
      surface: BrandColors.surface,
      onSurface: BrandColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: BrandColors.cream,
      canvasColor: BrandColors.cream,
      fontFamily: BrandFonts.text,
      splashFactory: NoSplash.splashFactory,
      shadowColor: BrandColors.ink,
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.cream,
        foregroundColor: BrandColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: BrandColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: const DialogThemeData(
        elevation: 0,
        backgroundColor: BrandColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        backgroundColor: BrandColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: TextTheme(
        displayLarge: BrandText.sectionTitle(size: 46),
        displayMedium: BrandText.sectionTitle(),
        headlineSmall: BrandText.sectionTitle(size: 26),
        titleMedium: BrandText.cardTitle(),
        bodyMedium: BrandText.body(),
        bodySmall: BrandText.caption(),
        labelLarge: BrandText.action(),
        labelSmall: BrandText.eyebrow(),
      ),
    );
  }
}
