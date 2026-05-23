import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../constants/app_constants.dart';
import '../../features/alarm/domain/alarm.dart';

/// Notification action ids used by the engine.
class NotificationActions {
  NotificationActions._();
  static const String snooze = 'alarm_action_snooze';
  static const String dismiss = 'alarm_action_dismiss';
}

/// Payload schema used for every alarm notification.
///
/// Encoded as `"alarmId|fireMillisUtc"` so the background isolate can
/// reconstruct it without a JSON dependency.
class AlarmNotificationPayload {
  const AlarmNotificationPayload({required this.alarmId, required this.fireMillisUtc});

  final int alarmId;
  final int fireMillisUtc;

  String encode() => '$alarmId|$fireMillisUtc';

  static AlarmNotificationPayload? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final List<String> parts = raw.split('|');
    if (parts.length != 2) return null;
    final int? id = int.tryParse(parts[0]);
    final int? when = int.tryParse(parts[1]);
    if (id == null || when == null) return null;
    return AlarmNotificationPayload(alarmId: id, fireMillisUtc: when);
  }
}

/// Thin wrapper around [FlutterLocalNotificationsPlugin] that:
///
/// * Installs the high-priority alarm channel on Android.
/// * Initialises the `timezone` database against the device's current zone.
/// * Builds [NotificationDetails] tuned for alarm-clock UX (full-screen
///   intent, alarm category, snooze + dismiss actions).
///
/// **Background isolate note**: this service is designed so the same
/// instance configuration works both in the UI isolate *and* in the
/// background isolate spawned by `android_alarm_manager_plus`. The static
/// callbacks (`onDidReceiveNotificationResponse`,
/// `onDidReceiveBackgroundNotificationResponse`) must be top-level / static
/// — they are assigned in [initialize].
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// The underlying plugin instance. Exposed so other services
  /// ([PermissionService], [AlarmService]) can share a single instance.
  final FlutterLocalNotificationsPlugin plugin;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialises the plugin, the notification channel and the timezone DB.
  ///
  /// Idempotent — calling this multiple times is a no-op.
  Future<void> initialize({
    DidReceiveNotificationResponseCallback? onForegroundAction,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundAction,
  }) async {
    if (_initialized) return;

    // 1) Timezone database.
    tzdata.initializeTimeZones();
    try {
      final String localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: failed to resolve local timezone ($e). '
          'Falling back to UTC.',
        );
      }
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 2) Platform-specific init settings.
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          AppConstants.alarmChannelId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              NotificationActions.snooze,
              'Snooze',
            ),
            DarwinNotificationAction.plain(
              NotificationActions.dismiss,
              'Dismiss',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
      ],
    );

    final InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onForegroundAction,
      onDidReceiveBackgroundNotificationResponse: onBackgroundAction,
    );

    // 3) Create the high-priority alarm channel (Android 8+).
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android = plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        AppConstants.alarmChannelId,
        AppConstants.alarmChannelName,
        description: AppConstants.alarmChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      await android?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  /// Builds the [NotificationDetails] used for a *fired* alarm. The same
  /// details are used for both scheduled-by-flutter_local_notifications and
  /// background-isolate fired notifications.
  NotificationDetails buildAlarmDetails(Alarm alarm) {
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      AppConstants.alarmChannelId,
      AppConstants.alarmChannelName,
      channelDescription: AppConstants.alarmChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      // Keep the notification on screen until the user dismisses it.
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: alarm.vibrate,
      visibility: NotificationVisibility.public,
      ticker: 'Alarm: ${alarm.label}',
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          NotificationActions.snooze,
          'Snooze',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          NotificationActions.dismiss,
          'Dismiss',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const DarwinNotificationDetails darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: AppConstants.alarmChannelId,
    );

    return NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }
}
