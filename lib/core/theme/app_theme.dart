import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0B6668);
  static const primaryDark = Color(0xFF084E50);
  static const primaryContainer = Color(0xFFD8EEEE);
  static const background = Color(0xFFF3F7F7);
  static const surface = Color(0xFFFCFEFE);
  static const surfaceMuted = Color(0xFFEAF0F0);
  static const surfaceStrong = Color(0xFFDCE7E7);
  static const border = Color(0xFFCFDBDC);
  static const normal = Color(0xFF19733B);
  static const normalContainer = Color(0xFFD8F3DF);
  static const warning = Color(0xFF995200);
  static const warningContainer = Color(0xFFFFE2BD);
  static const risk = Color(0xFFB3261E);
  static const riskContainer = Color(0xFFFFDAD6);
  static const outline = Color(0xFF586768);
  static const ink = Color(0xFF172526);
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.surface,
          error: AppColors.risk,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.surface,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.primaryDark,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          outline: AppColors.outline,
          outlineVariant: AppColors.border,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'sans-serif',
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 48,
          height: 1.05,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(fontSize: 18, height: 1.5, color: AppColors.ink),
        bodyMedium: TextStyle(fontSize: 16, height: 1.45, color: AppColors.ink),
        bodySmall: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: AppColors.outline,
        ),
        labelLarge: TextStyle(
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: TextStyle(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 58),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.surfaceStrong,
          disabledForegroundColor: AppColors.outline,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 58),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.risk),
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.primaryDark : AppColors.outline,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primaryDark : AppColors.outline,
            size: 25,
          );
        }),
      ),
    );
  }
}
