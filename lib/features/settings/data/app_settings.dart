import 'package:flutter/material.dart';

/// Available app languages.
enum AppLanguage {
  arabic('ar'),
  english('en');

  const AppLanguage(this.code);

  /// Locale code used by [Locale].
  final String code;

  Locale toLocale() => Locale(code);

  static AppLanguage fromCode(String? code) {
    switch (code) {
      case 'ar':
        return AppLanguage.arabic;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }
}

/// Built-in ringtone identifiers. The actual playback is owned by the
/// alarm-engine module; this enum keeps the user's preferred selection.
enum DefaultRingtone {
  classic,
  digital,
  gentle,
  rooster,
  ocean;

  static DefaultRingtone fromName(String? name) {
    return DefaultRingtone.values.firstWhere(
      (r) => r.name == name,
      orElse: () => DefaultRingtone.classic,
    );
  }
}

/// Immutable snapshot of all user-configurable preferences.
@immutable
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.language,
    required this.use24hFormat,
    required this.defaultSnoozeMinutes,
    required this.defaultRingtone,
  });

  final ThemeMode themeMode;
  final AppLanguage language;
  final bool use24hFormat;
  final int defaultSnoozeMinutes;
  final DefaultRingtone defaultRingtone;

  /// Sensible defaults: follow system theme, English, 24h format, 5-min snooze.
  static const AppSettings defaults = AppSettings(
    themeMode: ThemeMode.system,
    language: AppLanguage.english,
    use24hFormat: true,
    defaultSnoozeMinutes: 5,
    defaultRingtone: DefaultRingtone.classic,
  );

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppLanguage? language,
    bool? use24hFormat,
    int? defaultSnoozeMinutes,
    DefaultRingtone? defaultRingtone,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      use24hFormat: use24hFormat ?? this.use24hFormat,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
      defaultRingtone: defaultRingtone ?? this.defaultRingtone,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.language == language &&
        other.use24hFormat == use24hFormat &&
        other.defaultSnoozeMinutes == defaultSnoozeMinutes &&
        other.defaultRingtone == defaultRingtone;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    language,
    use24hFormat,
    defaultSnoozeMinutes,
    defaultRingtone,
  );
}

/// Catalog of allowed snooze durations exposed in the UI.
const List<int> kAllowedSnoozeMinutes = <int>[1, 3, 5, 10, 15, 20, 30];
