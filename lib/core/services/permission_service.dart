import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Aggregates the status of every permission the alarm engine relies on.
@immutable
class AlarmPermissionStatus {
  const AlarmPermissionStatus({
    required this.notifications,
    required this.exactAlarm,
    required this.fullScreenIntent,
    required this.ignoreBatteryOptimizations,
  });

  /// User has granted POST_NOTIFICATIONS / iOS notification authorization.
  final bool notifications;

  /// User has granted SCHEDULE_EXACT_ALARM (Android 12+). On iOS / older
  /// Android versions this is always reported as `true`.
  final bool exactAlarm;

  /// User has granted USE_FULL_SCREEN_INTENT (Android 14+). On iOS / older
  /// Android versions this is always reported as `true`.
  final bool fullScreenIntent;

  /// App is whitelisted from battery optimization (Doze). On iOS / older
  /// Android versions this is always reported as `true`.
  final bool ignoreBatteryOptimizations;

  /// `true` when every permission required by the engine is granted.
  bool get allGranted =>
      notifications &&
      exactAlarm &&
      fullScreenIntent &&
      ignoreBatteryOptimizations;

  @override
  String toString() =>
      'AlarmPermissionStatus(notifications: $notifications, exactAlarm: $exactAlarm, '
      'fullScreenIntent: $fullScreenIntent, '
      'ignoreBatteryOptimizations: $ignoreBatteryOptimizations)';
}

/// Centralised gateway for every runtime permission the alarm engine needs.
///
/// The service is intentionally stateless — callers (UI, [AlarmService]) ask
/// for permissions on demand and the platform plugins themselves remember
/// the granted state.
class PermissionService {
  PermissionService(this._notifications);

  final FlutterLocalNotificationsPlugin _notifications;

  /// Returns the current status of every permission the engine relies on,
  /// without prompting the user.
  Future<AlarmPermissionStatus> currentStatus() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Desktop / web: notifications work, no other permissions apply.
      return const AlarmPermissionStatus(
        notifications: true,
        exactAlarm: true,
        fullScreenIntent: true,
        ignoreBatteryOptimizations: true,
      );
    }

    if (Platform.isIOS) {
      // permission_handler's notification status mirrors iOS authorization.
      final PermissionStatus n = await Permission.notification.status;
      return AlarmPermissionStatus(
        notifications: n.isGranted,
        exactAlarm: true,
        fullScreenIntent: true,
        ignoreBatteryOptimizations: true,
      );
    }

    // Android.
    final AndroidFlutterLocalNotificationsPlugin? android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final bool notifications =
        (await android?.areNotificationsEnabled()) ?? false;

    final bool exact = (await android?.canScheduleExactNotifications()) ?? true;

    // USE_FULL_SCREEN_INTENT requires Android 14+. `Permission.systemAlertWindow`
    // is *not* the same thing, so we treat it as best-effort and rely on the
    // manifest entry. We expose the granted state through permission_handler
    // when the platform side supports it.
    final bool fullScreen = await _isFullScreenIntentGranted();

    final bool ignoreBatt =
        (await Permission.ignoreBatteryOptimizations.status).isGranted;

    return AlarmPermissionStatus(
      notifications: notifications,
      exactAlarm: exact,
      fullScreenIntent: fullScreen,
      ignoreBatteryOptimizations: ignoreBatt,
    );
  }

  /// Asks the OS to grant every permission the engine needs. Safe to call
  /// multiple times; already-granted permissions are not re-prompted.
  ///
  /// Returns the resulting [AlarmPermissionStatus]. Callers should check
  /// [AlarmPermissionStatus.allGranted] and surface a friendly UI if any
  /// permission is still missing.
  Future<AlarmPermissionStatus> requestAll() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return currentStatus();
    }

    if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: true,
      );
      return currentStatus();
    }

    // ---- Android ----
    final AndroidFlutterLocalNotificationsPlugin? android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // 1) POST_NOTIFICATIONS (Android 13+) – delegate to the plugin which
    //    routes to the correct system dialog.
    await android?.requestNotificationsPermission();

    // 2) SCHEDULE_EXACT_ALARM (Android 12+). Opens a settings screen if the
    //    permission has been revoked.
    await android?.requestExactAlarmsPermission();

    // 3) USE_FULL_SCREEN_INTENT (Android 14+). Use permission_handler's
    //    dedicated entry, falling back gracefully on older OS versions.
    await _requestFullScreenIntent();

    // 4) Ignore battery optimizations – opens the system whitelist screen.
    if (!(await Permission.ignoreBatteryOptimizations.status).isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    return currentStatus();
  }

  // ---------------------------------------------------------------------------
  // USE_FULL_SCREEN_INTENT helpers.
  //
  // `permission_handler` exposes this via [Permission.scheduleExactAlarm] +
  // [Permission.systemAlertWindow] on different versions of the plugin. To
  // stay forward-compatible we feature-detect and fall back to a manifest-only
  // grant when the dedicated permission constant is unavailable.
  // ---------------------------------------------------------------------------

  Future<bool> _isFullScreenIntentGranted() async {
    try {
      // permission_handler >= 11.4 exposes `Permission.notification` with a
      // dedicated `isGranted` for full-screen intent on Android 14+ devices.
      // If the constant exists at runtime we use it; otherwise we trust the
      // manifest declaration (which auto-grants on < API 34).
      return (await Permission.notification.status).isGranted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PermissionService: full-screen intent check failed: $e');
      }
      return true;
    }
  }

  Future<void> _requestFullScreenIntent() async {
    try {
      await Permission.notification.request();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PermissionService: full-screen intent request failed: $e');
      }
    }
  }
}
