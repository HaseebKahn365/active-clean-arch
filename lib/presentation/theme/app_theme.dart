import 'package:flutter/material.dart';
import 'app_color_schemes.dart';

class AppTheme {
  static ThemeData getTheme(ColorProfile profile, Brightness brightness) {
    final colorScheme = AppColorScheme.getColorScheme(profile, brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        bodyLarge: TextStyle(fontSize: 16, color: colorScheme.onSurface),
        bodyMedium: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.light ? Colors.white : colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: brightness == Brightness.light ? Colors.grey.withAlpha(50) : Colors.white.withAlpha(20),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
    );
  }
}
