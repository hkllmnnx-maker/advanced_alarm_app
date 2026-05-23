/// Global constants used across the application.
///
/// Keep this file dependency-free (pure Dart) so it can be imported anywhere.
class AppConstants {
  AppConstants._();

  /// Public-facing display name of the application.
  static const String appName = 'Advanced Alarm App';

  /// Semantic application version (kept in sync with pubspec.yaml).
  static const String appVersion = '1.0.0';

  // ---------------------------------------------------------------------------
  // Notification channels (Android)
  // ---------------------------------------------------------------------------

  /// Channel id used for high-priority alarm notifications.
  static const String alarmChannelId = 'advanced_alarm_channel';

  /// Channel name shown to the user in Android system settings.
  static const String alarmChannelName = 'Alarms';

  /// Channel description shown to the user in Android system settings.
  static const String alarmChannelDescription =
      'Channel used to deliver scheduled alarm notifications.';

  // ---------------------------------------------------------------------------
  // Local storage (Hive)
  // ---------------------------------------------------------------------------

  /// Name of the Hive box that will later store alarm entities.
  static const String alarmsBoxName = 'alarms_box';

  /// Name of the Hive box that will later store user preferences/settings.
  static const String settingsBoxName = 'settings_box';
}
