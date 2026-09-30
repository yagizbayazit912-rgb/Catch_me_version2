import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Yuvarlak köşe yarıçapları (plan: 16–24 px).
abstract final class AppRadii {
  static const double card = 24;
  static const double button = 20;
  static const double input = 16;
}

abstract final class AppTheme {
  static const fontFamily = 'Nunito';

  static final _softShadow = BoxShadow(
    color: AppColors.text.withValues(alpha: 0.08),
    blurRadius: 16,
    offset: const Offset(0, 6),
  );

  /// Kartlar/paneller için ortak yumuşak gölge.
  static List<BoxShadow> get softShadow => [_softShadow];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.text,
      secondary: AppColors.secondary,
      onSecondary: AppColors.text,
      tertiary: AppColors.accentLavender,
      error: AppColors.warning,
      onError: AppColors.text,
      surface: AppColors.surface,
      onSurface: AppColors.text,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.button),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    final buttonText = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 16,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.text,
          elevation: 3,
          shadowColor: AppColors.primary.withValues(alpha: 0.6),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.text,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.primary, width: 2),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.text,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: AppColors.text.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.accentButter,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
