import 'package:flutter/material.dart';
import 'app_colors.dart';

enum ColorProfile { activeBlue, deepForest, sunsetOrange }

class AppColorScheme {
  static ColorScheme getActiveBlue(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF),
      secondary: AppColors.success,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: isDark ? AppColors.bgDark : AppColors.bgLight,
      onSurface: isDark ? AppColors.textMainDark : AppColors.textMainLight,
      surfaceContainerLow: isDark ? const Color(0xFF0A0C10) : const Color(0xFFF1F5F9),
      surfaceContainer: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
      surfaceContainerHigh: isDark ? const Color(0xFF1E252E) : const Color(0xFFEDF2F7),
      surfaceContainerHighest: isDark ? const Color(0xFF262C36) : const Color(0xFFE2E8F0),
      onSurfaceVariant: isDark ? AppColors.textSubDark : AppColors.textSubLight,
      outline: isDark ? AppColors.borderDark : AppColors.borderLight,
      outlineVariant: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
    );
  }

  static ColorScheme getDeepForest(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const forestPrimary = Color(0xFF15803D);

    return ColorScheme(
      brightness: brightness,
      primary: forestPrimary,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF062D17) : const Color(0xFFDCFCE7),
      secondary: const Color(0xFF84CC16),
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: isDark ? const Color(0xFF020403) : const Color(0xFFF0FDF4),
      onSurface: isDark ? AppColors.textMainDark : const Color(0xFF14532D),
      surfaceContainerLow: isDark ? const Color(0xFF040806) : const Color(0xFFF7FEE7),
      surfaceContainer: isDark ? const Color(0xFF08100C) : Colors.white,
      surfaceContainerHigh: isDark ? const Color(0xFF0D1812) : const Color(0xFFF1FDF6),
      surfaceContainerHighest: isDark ? const Color(0xFF132219) : const Color(0xFFDCFCE7),
      onSurfaceVariant: isDark ? AppColors.textSubDark : const Color(0xFF166534),
      outline: isDark ? const Color(0xFF142F1F) : const Color(0xFFDCFCE7),
      outlineVariant: isDark ? const Color(0xFF0B1B12) : const Color(0xFFF1FDF6),
    );
  }

  static ColorScheme getSunsetOrange(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const sunsetPrimary = Color(0xFFF97316);

    return ColorScheme(
      brightness: brightness,
      primary: sunsetPrimary,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF431407) : const Color(0xFFFFEDD5),
      secondary: const Color(0xFFFACC15),
      onSecondary: const Color(0xFF431407),
      error: AppColors.error,
      onError: Colors.white,
      surface: isDark ? const Color(0xFF0A0502) : const Color(0xFFFFF7ED),
      onSurface: isDark ? AppColors.textMainDark : const Color(0xFF431407),
      surfaceContainerLow: isDark ? const Color(0xFF0F0804) : const Color(0xFFFFF7ED),
      surfaceContainer: isDark ? const Color(0xFF170D08) : Colors.white,
      surfaceContainerHigh: isDark ? const Color(0xFF23140C) : const Color(0xFFFFF5EB),
      surfaceContainerHighest: isDark ? const Color(0xFF2D1810) : const Color(0xFFFFEDD5),
      onSurfaceVariant: isDark ? AppColors.textSubDark : const Color(0xFF9A3412),
      outline: isDark ? const Color(0xFF2D1810) : const Color(0xFFFFEDD5),
      outlineVariant: isDark ? const Color(0xFF1C0F0A) : const Color(0xFFFFF9F5),
    );
  }

  static ColorScheme getColorScheme(ColorProfile profile, Brightness brightness) {
    switch (profile) {
      case ColorProfile.activeBlue:
        return getActiveBlue(brightness);
      case ColorProfile.deepForest:
        return getDeepForest(brightness);
      case ColorProfile.sunsetOrange:
        return getSunsetOrange(brightness);
    }
  }
}
