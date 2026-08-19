import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // Light Palette
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurfaceCard = Color(0xFFFAFAFA);
  static const Color lightSurfaceSubtle = Color(0xFFF4F4F5);
  static const Color lightSurfaceDark = Color(0xFF111113);

  static const Color lightBorderCard = Color(0xFFEEEEEE);
  static const Color lightBorderSubtle = Color(0xFFECECEE);
  static const Color lightBorderDivider = Color(0xFFF0F0F1);

  static const Color lightTextPrimary = Color(0xFF0A0A0A);
  static const Color lightTextSecondary = Color(0xFF71717A);
  static const Color lightTextMuted = Color(0xFFA1A1AA);
  static const Color lightTextSubtle = Color(0xFFC4C4C9);
  static const Color lightTextOnDark = Color(0xFFFFFFFF);

  static const Color lightTimeIconBg = Color(0xFFEEF2FF);
  static const Color lightTimeIcon = Color(0xFF4F46E5);
  static const Color lightCountIconBg = Color(0xFFF0FDF4);
  static const Color lightCountIcon = Color(0xFF16A34A);

  static const Color lightBadgeTodayBg = Color(0xFFFFF7D6);
  static const Color lightBadgeTodayText = Color(0xFF7A5B00);
  static const Color lightBadgeTodayIcon = Color(0xFFC99700);

  static const Color lightBadgeBestBg = Color(0xFFF4F4F5);
  static const Color lightBadgeBestText = Color(0xFF52525B);
  static const Color lightBadgeBestIcon = Color(0xFFA1A1AA);

  // Dark Palette (Deep Obsidian / Carbon with vibrant intentional accents)
  static const Color darkBackground = Color(0xFF0A0A0C);
  static const Color darkSurfaceCard = Color(0xFF14151B);
  static const Color darkSurfaceSubtle = Color(0xFF1E202A);
  static const Color darkSurfaceDark = Color(0xFFFFFFFF);

  static const Color darkBorderCard = Color(0xFF232532);
  static const Color darkBorderSubtle = Color(0xFF2A2D3C);
  static const Color darkBorderDivider = Color(0xFF1C1E28);

  static const Color darkTextPrimary = Color(0xFFF4F4F6);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkTextMuted = Color(0xFF71717A);
  static const Color darkTextSubtle = Color(0xFF52525B);
  static const Color darkTextOnDark = Color(0xFF0A0A0C);

  static const Color darkTimeIconBg = Color(0xFF1E2238);
  static const Color darkTimeIcon = Color(0xFF818CF8);
  static const Color darkCountIconBg = Color(0xFF162A1F);
  static const Color darkCountIcon = Color(0xFF4ADE80);

  static const Color darkBadgeTodayBg = Color(0xFF2E260A);
  static const Color darkBadgeTodayText = Color(0xFFFDE047);
  static const Color darkBadgeTodayIcon = Color(0xFFFACC15);

  static const Color darkBadgeBestBg = Color(0xFF1E202A);
  static const Color darkBadgeBestText = Color(0xFFA1A1AA);
  static const Color darkBadgeBestIcon = Color(0xFF71717A);

  // Static shared accents
  static const Color goldAccent = Color(0xFFF5C400);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBgDark = Color(0xFF2A1517);

  // Compatibility backwards-compatible getters defaulting to light
  static const Color background = lightBackground;
  static const Color surfaceCard = lightSurfaceCard;
  static const Color surfaceSubtle = lightSurfaceSubtle;
  static const Color surfaceDark = lightSurfaceDark;
  static const Color borderCard = lightBorderCard;
  static const Color borderSubtle = lightBorderSubtle;
  static const Color borderDivider = lightBorderDivider;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color textMuted = lightTextMuted;
  static const Color textSubtle = lightTextSubtle;
  static const Color textOnDark = lightTextOnDark;
  static const Color timeIconBg = lightTimeIconBg;
  static const Color timeIcon = lightTimeIcon;
  static const Color countIconBg = lightCountIconBg;
  static const Color countIcon = lightCountIcon;
  static const Color badgeTodayBg = lightBadgeTodayBg;
  static const Color badgeTodayText = lightBadgeTodayText;
  static const Color badgeTodayIcon = lightBadgeTodayIcon;
  static const Color badgeBestBg = lightBadgeBestBg;
  static const Color badgeBestText = lightBadgeBestText;
  static const Color badgeBestIcon = lightBadgeBestIcon;

  // Dynamic Accessors based on brightness
  static Color getBackground(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color getSurfaceCard(bool isDark) => isDark ? darkSurfaceCard : lightSurfaceCard;
  static Color getSurfaceSubtle(bool isDark) => isDark ? darkSurfaceSubtle : lightSurfaceSubtle;
  static Color getSurfaceDark(bool isDark) => isDark ? darkSurfaceDark : lightSurfaceDark;
  static Color getBorderCard(bool isDark) => isDark ? darkBorderCard : lightBorderCard;
  static Color getBorderSubtle(bool isDark) => isDark ? darkBorderSubtle : lightBorderSubtle;
  static Color getBorderDivider(bool isDark) => isDark ? darkBorderDivider : lightBorderDivider;
  static Color getTextPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color getTextSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color getTextMuted(bool isDark) => isDark ? darkTextMuted : lightTextMuted;
  static Color getTextSubtle(bool isDark) => isDark ? darkTextSubtle : lightTextSubtle;
  static Color getTextOnDark(bool isDark) => isDark ? darkTextOnDark : lightTextOnDark;

  static Color getTimeIconBg(bool isDark) => isDark ? darkTimeIconBg : lightTimeIconBg;
  static Color getTimeIcon(bool isDark) => isDark ? darkTimeIcon : lightTimeIcon;
  static Color getCountIconBg(bool isDark) => isDark ? darkCountIconBg : lightCountIconBg;
  static Color getCountIcon(bool isDark) => isDark ? darkCountIcon : lightCountIcon;

  static Color getBadgeTodayBg(bool isDark) => isDark ? darkBadgeTodayBg : lightBadgeTodayBg;
  static Color getBadgeTodayText(bool isDark) => isDark ? darkBadgeTodayText : lightBadgeTodayText;
  static Color getBadgeTodayIcon(bool isDark) => isDark ? darkBadgeTodayIcon : lightBadgeTodayIcon;

  static Color getBadgeBestBg(bool isDark) => isDark ? darkBadgeBestBg : lightBadgeBestBg;
  static Color getBadgeBestText(bool isDark) => isDark ? darkBadgeBestText : lightBadgeBestText;
  static Color getBadgeBestIcon(bool isDark) => isDark ? darkBadgeBestIcon : lightBadgeBestIcon;
}

class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.lightSurfaceDark,
      onPrimary: AppColors.lightTextOnDark,
      secondary: AppColors.lightSurfaceDark,
      onSecondary: AppColors.lightTextOnDark,
      surface: AppColors.lightBackground,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainer: AppColors.lightSurfaceCard,
      surfaceContainerHigh: AppColors.lightSurfaceSubtle,
      surfaceContainerHighest: AppColors.lightSurfaceSubtle,
      surfaceContainerLow: AppColors.lightSurfaceCard,
      outline: AppColors.lightBorderSubtle,
      outlineVariant: AppColors.lightBorderCard,
      error: AppColors.error,
      onError: AppColors.lightTextOnDark,
      errorContainer: AppColors.errorBg,
      onErrorContainer: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: colorScheme,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: _buildTextTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary, AppColors.lightTextMuted),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorderDivider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: _buildInputTheme(AppColors.lightBackground, AppColors.lightBorderSubtle, AppColors.lightSurfaceDark),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.darkSurfaceDark,
      onPrimary: AppColors.darkTextOnDark,
      secondary: AppColors.darkSurfaceDark,
      onSecondary: AppColors.darkTextOnDark,
      surface: AppColors.darkBackground,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainer: AppColors.darkSurfaceCard,
      surfaceContainerHigh: AppColors.darkSurfaceSubtle,
      surfaceContainerHighest: AppColors.darkSurfaceSubtle,
      surfaceContainerLow: AppColors.darkSurfaceCard,
      outline: AppColors.darkBorderSubtle,
      outlineVariant: AppColors.darkBorderCard,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorBgDark,
      onErrorContainer: Color(0xFFFCA5A5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: colorScheme,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: _buildTextTheme(AppColors.darkTextPrimary, AppColors.darkTextSecondary, AppColors.darkTextMuted),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorderDivider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: _buildInputTheme(AppColors.darkSurfaceCard, AppColors.darkBorderSubtle, AppColors.darkSurfaceDark),
    );
  }

  static ThemeData get theme => lightTheme;

  static TextTheme _buildTextTheme(Color primary, Color secondary, Color muted) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -0.6,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -0.4,
      ),
      titleMedium: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.2,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: muted,
      ),
    );
  }

  static InputDecorationTheme _buildInputTheme(Color fillColor, Color borderColor, Color focusedColor) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      hintStyle: const TextStyle(
        color: AppColors.lightTextMuted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: focusedColor, width: 1.5),
      ),
    );
  }
}
