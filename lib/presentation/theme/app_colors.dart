import 'package:flutter/material.dart';

class AppColors {
  // --- CORE PALETTE (Base Tones) ---

  // Primary: Active Indigo
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);

  // Semantic Accents
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color info = Color(0xFF3B82F6); // Blue 500

  // --- NEUTRALS (Light Mode) ---
  static const Color bgLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF); // White
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color textMainLight = Color(0xFF0F172A); // Slate 900
  static const Color textSubLight = Color(0xFF64748B); // Slate 500

  // --- NEUTRALS (Dark Mode) ---
  // Using deep carbon-ink for true dark feel
  static const Color bgDark = Color(0xFF030408); // Near black
  static const Color surfaceDark = Color(0xFF0D1117); // Darker gray
  static const Color surfaceCardDark = Color(0xFF161B22); // Elevation 1
  static const Color borderDark = Color(0xFF30363D); // Subtle line
  static const Color textMainDark = Color(0xFFF0F6FC); // Crisp white
  static const Color textSubDark = Color(0xFF8B949E); // Muted gray

  // --- VISUALIZATION COLORS ---
  static const List<Color> chartPalette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
  ];

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
