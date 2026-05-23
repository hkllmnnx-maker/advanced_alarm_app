import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Thin persistence layer on top of [SharedPreferences].
///
/// Keeps all storage keys in one place and is the single async boundary for
/// settings I/O — the rest of the app talks to [SettingsProvider] only.
class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _kThemeMode = 'settings.theme_mode';
  static const _kLanguage = 'settings.language';
  static const _kUse24h = 'settings.use_24h';
  static const _kSnoozeMinutes = 'settings.snooze_minutes';
  static const _kRingtone = 'settings.default_ringtone';

  final SharedPreferences _prefs;

  /// Read the latest snapshot from disk. Missing keys fall back to
  /// [AppSettings.defaults] so first-launch is fully functional.
  AppSettings load() {
    final theme = _readThemeMode();
    final lang = AppLanguage.fromCode(_prefs.getString(_kLanguage));
    final use24h = _prefs.getBool(_kUse24h) ?? AppSettings.defaults.use24hFormat;
    final snooze = _prefs.getInt(_kSnoozeMinutes) ??
        AppSettings.defaults.defaultSnoozeMinutes;
    final ringtone = DefaultRingtone.fromName(_prefs.getString(_kRingtone));

    return AppSettings(
      themeMode: theme,
      language: lang,
      use24hFormat: use24h,
      defaultSnoozeMinutes: snooze,
      defaultRingtone: ringtone,
    );
  }

  /// Persist a full snapshot. Writes are independent so a partial failure
  /// can never leave the store in an inconsistent state.
  Future<void> save(AppSettings s) async {
    await Future.wait<void>([
      _prefs.setString(_kThemeMode, _themeModeToString(s.themeMode)),
      _prefs.setString(_kLanguage, s.language.code),
      _prefs.setBool(_kUse24h, s.use24hFormat),
      _prefs.setInt(_kSnoozeMinutes, s.defaultSnoozeMinutes),
      _prefs.setString(_kRingtone, s.defaultRingtone.name),
    ]);
  }

  ThemeMode _readThemeMode() {
    switch (_prefs.getString(_kThemeMode)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return AppSettings.defaults.themeMode;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
