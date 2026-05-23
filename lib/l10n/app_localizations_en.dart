// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Advanced Alarm';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionAlarms => 'Alarms';

  @override
  String get sectionDanger => 'Danger zone';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageEnglish => 'English';

  @override
  String get timeFormat => 'Time format';

  @override
  String get timeFormat24 => '24-hour';

  @override
  String get timeFormat12 => '12-hour';

  @override
  String get defaultSnooze => 'Default snooze duration';

  @override
  String snoozeMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get defaultRingtone => 'Default ringtone';

  @override
  String get ringtoneClassic => 'Classic Bell';

  @override
  String get ringtoneDigital => 'Digital Beep';

  @override
  String get ringtoneGentle => 'Gentle Chimes';

  @override
  String get ringtoneRooster => 'Morning Rooster';

  @override
  String get ringtoneOcean => 'Ocean Waves';

  @override
  String get resetAllAlarms => 'Reset all alarms';

  @override
  String get resetAllAlarmsDescription =>
      'Permanently delete every alarm. This action cannot be undone.';

  @override
  String get resetConfirmTitle => 'Reset all alarms?';

  @override
  String get resetConfirmMessage =>
      'All alarms will be permanently deleted. This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get alarmsResetSnack => 'All alarms have been deleted.';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get homeNoSettingsHint => 'Tap the gear icon to open Settings.';
}
