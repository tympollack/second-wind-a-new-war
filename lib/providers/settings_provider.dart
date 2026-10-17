import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  final bool hapticsEnabled;
  final String primaryColorOverride; // 'auto', 'cyan', 'orange'

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.hapticsEnabled = true,
    this.primaryColorOverride = 'auto',
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? hapticsEnabled,
    String? primaryColorOverride,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      primaryColorOverride: primaryColorOverride ?? this.primaryColorOverride,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _themeModeKey = 'settings_theme_mode';
  static const _hapticsKey = 'settings_haptics_enabled';
  static const _primaryColorKey = 'settings_primary_color';

  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      ThemeMode mode = ThemeMode.system;
      final savedTheme = prefs.getString(_themeModeKey);
      if (savedTheme == 'light') mode = ThemeMode.light;
      if (savedTheme == 'dark') mode = ThemeMode.dark;

      final haptics = prefs.getBool(_hapticsKey) ?? true;
      final colorOverride = prefs.getString(_primaryColorKey) ?? 'auto';

      state = state.copyWith(
        themeMode: mode,
        hapticsEnabled: haptics,
        primaryColorOverride: colorOverride,
      );
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String modeStr = 'system';
      if (mode == ThemeMode.light) modeStr = 'light';
      if (mode == ThemeMode.dark) modeStr = 'dark';
      
      await prefs.setString(_themeModeKey, modeStr);
      state = state.copyWith(themeMode: mode);
    } catch (e) {
      debugPrint('Failed to save theme setting: $e');
    }
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hapticsKey, enabled);
      state = state.copyWith(hapticsEnabled: enabled);
    } catch (e) {
      debugPrint('Failed to save haptics setting: $e');
    }
  }

  Future<void> setPrimaryColorOverride(String color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_primaryColorKey, color);
      state = state.copyWith(primaryColorOverride: color);
    } catch (e) {
      debugPrint('Failed to save primary color setting: $e');
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
