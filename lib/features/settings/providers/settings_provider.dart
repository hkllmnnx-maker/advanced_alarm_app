import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_settings.dart';
import '../data/settings_repository.dart';

/// Reactive holder for [AppSettings].
///
/// Wire it once at the root of the widget tree and read it everywhere via
/// [Provider.of] / [Consumer]. Any change is persisted to [SharedPreferences]
/// in the background, but listeners are notified synchronously so the UI
/// updates instantly (no app restart required for theme or locale).
class SettingsProvider extends ChangeNotifier {
  SettingsProvider._(this._repository, this._settings);

  /// Create a fully-initialized provider. Reads persisted values once;
  /// callers should `await` this before `runApp` so the first frame already
  /// reflects the user's preferences.
  static Future<SettingsProvider> create() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs);
    return SettingsProvider._(repo, repo.load());
  }

  final SettingsRepository _repository;
  AppSettings _settings;

  AppSettings get settings => _settings;

  ThemeMode get themeMode => _settings.themeMode;
  AppLanguage get language => _settings.language;
  Locale get locale => _settings.language.toLocale();
  bool get use24hFormat => _settings.use24hFormat;
  int get defaultSnoozeMinutes => _settings.defaultSnoozeMinutes;
  DefaultRingtone get defaultRingtone => _settings.defaultRingtone;

  // ---------------------------------------------------------------------------
  // Mutators – each method notifies listeners immediately and persists
  // asynchronously. Errors during persistence are surfaced via debugPrint
  // only; the in-memory state is the source of truth.
  // ---------------------------------------------------------------------------

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(_settings.copyWith(themeMode: mode));

  Future<void> setLanguage(AppLanguage language) =>
      _update(_settings.copyWith(language: language));

  Future<void> setUse24hFormat(bool value) =>
      _update(_settings.copyWith(use24hFormat: value));

  Future<void> setDefaultSnoozeMinutes(int minutes) =>
      _update(_settings.copyWith(defaultSnoozeMinutes: minutes));

  Future<void> setDefaultRingtone(DefaultRingtone ringtone) =>
      _update(_settings.copyWith(defaultRingtone: ringtone));

  /// Reset every preference to [AppSettings.defaults].
  Future<void> resetToDefaults() => _update(AppSettings.defaults);

  Future<void> _update(AppSettings next) async {
    if (next == _settings) return;
    _settings = next;
    notifyListeners();
    try {
      await _repository.save(next);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SettingsProvider: failed to persist settings: $e\n$st');
      }
    }
  }
}
