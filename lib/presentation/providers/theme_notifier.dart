import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/injection_container.dart';
import '../theme/app_color_schemes.dart';

class ThemeState {
  final ThemeMode themeMode;
  final ColorProfile colorProfile;

  ThemeState({required this.themeMode, required this.colorProfile});

  ThemeState copyWith({ThemeMode? themeMode, ColorProfile? colorProfile}) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      colorProfile: colorProfile ?? this.colorProfile,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const String _themeModeKey = 'theme_mode';
  static const String _colorProfileKey = 'color_profile';

  late SharedPreferences _prefs;

  @override
  ThemeState build() {
    _prefs = sl<SharedPreferences>();
    
    final modeIndex = _prefs.getInt(_themeModeKey);
    final profileIndex = _prefs.getInt(_colorProfileKey);

    ThemeMode mode = ThemeMode.system;
    ColorProfile profile = ColorProfile.activeBlue;

    if (modeIndex != null && modeIndex < ThemeMode.values.length) {
      mode = ThemeMode.values[modeIndex];
    }
    if (profileIndex != null && profileIndex < ColorProfile.values.length) {
      profile = ColorProfile.values[profileIndex];
    }

    return ThemeState(themeMode: mode, colorProfile: profile);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> setColorProfile(ColorProfile profile) async {
    state = state.copyWith(colorProfile: profile);
    await _prefs.setInt(_colorProfileKey, profile.index);
  }
}

final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
