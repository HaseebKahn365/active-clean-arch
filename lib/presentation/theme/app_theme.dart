import 'package:flutter/material.dart';
import 'app_color_schemes.dart';

class AppTheme {
  static ThemeData getTheme(ColorProfile profile, Brightness brightness) {
    final colorScheme = AppColorScheme.getColorScheme(profile, brightness);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: 'Inter',

      // Text Theme: Clear hierarchy and contrast
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        bodyLarge: TextStyle(fontSize: 16, color: colorScheme.onSurface, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant, height: 1.4),
      ),

      // Button Theme: Minimalist and solid
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      // Card Theme: Intentional surface separation
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outline.withValues(alpha: isDark ? 0.3 : 0.5), width: 1),
        ),
      ),

      // AppBar Theme: Transparent and clean
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 22),
      ),

      // Navigation Bar (if used)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.primary);
          }
          return TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant);
        }),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(color: colorScheme.outline.withValues(alpha: 0.2), space: 1, thickness: 1),
    );
  }
}
