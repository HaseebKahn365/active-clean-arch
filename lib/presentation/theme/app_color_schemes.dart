import 'package:flutter/material.dart';

enum ColorProfile { activeBlue, deepForest, sunsetOrange }

class AppColorScheme {
  static ColorScheme getActiveBlue(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      brightness: brightness,
      primary: const Color(0xFF6366F1),
      secondary: const Color(0xFF10B981),
      surface: brightness == Brightness.light ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
    );
  }

  static ColorScheme getDeepForest(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF15803D),
      brightness: brightness,
      primary: const Color(0xFF15803D),
      secondary: const Color(0xFF84CC16),
      surface: brightness == Brightness.light ? const Color(0xFFF0FDF4) : const Color(0xFF064E3B),
    );
  }

  static ColorScheme getSunsetOrange(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFFF97316),
      brightness: brightness,
      primary: const Color(0xFFF97316),
      secondary: const Color(0xFFFACC15),
      surface: brightness == Brightness.light ? const Color(0xFFFFF7ED) : const Color(0xFF431407),
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
