import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_color_schemes.dart';

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  static const String _themeModeKey = 'theme_mode';
  static const String _colorProfileKey = 'color_profile';

  ThemeProvider(this._prefs) {
    _loadFromPrefs();
  }

  ThemeMode _themeMode = ThemeMode.system;
  ColorProfile _colorProfile = ColorProfile.activeBlue;

  ThemeMode get themeMode => _themeMode;
  ColorProfile get colorProfile => _colorProfile;

  void _loadFromPrefs() {
    final modeIndex = _prefs.getInt(_themeModeKey);
    final profileIndex = _prefs.getInt(_colorProfileKey);

    if (modeIndex != null) {
      _themeMode = ThemeMode.values[modeIndex];
    }
    if (profileIndex != null) {
      _colorProfile = ColorProfile.values[profileIndex];
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  Future<void> setColorProfile(ColorProfile profile) async {
    _colorProfile = profile;
    await _prefs.setInt(_colorProfileKey, profile.index);
    notifyListeners();
  }
}
