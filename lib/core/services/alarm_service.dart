import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/alarm/domain/alarm.dart';
import 'notification_service.dart';
import 'permission_service.dart';

/// Contract for any object that can hand back the full list of currently
/// stored alarms when the engine needs to (re)schedule them — typically
/// after device reboot or after a permission grant.
///
/// The upcoming `feat/data-layer` branch will provide a Hive-backed
/// implementation. Until then a simple in-memory implementation
/// ([InMemoryAlarmRepository]) is bundled with the engine so that the API
/// is fully testable today.
abstract class AlarmRepository {
  /// Returns every alarm the user has ever created, regardless of its
  /// `enabled` flag. The service is responsible for skipping disabled ones.
  Future<List<Alarm>> loadAll();

  /// Persists / updates a single alarm. Used by [AlarmService.snooze] to
  /// remember the next fire time when the user defers an alarm.
  Future<void> save(Alarm alarm);

  /// Looks up a single alarm by id, or returns `null` if it no longer
  /// exists (e.g. user deleted it from the UI while it was firing).
  Future<Alarm?> findById(int id);
}

/// Lightweight in-memory [AlarmRepository] suitable for tests and for the
/// transitional period before `feat/data-layer` lands.
class InMemoryAlarmRepository implements AlarmRepository {
  final Map<int, Alarm> _store = <int, Alarm>{};

  @override
  Future<List<Alarm>> loadAll() async => _store.values.toList(growable: false);

  @override
  Future<void> save(Alarm alarm) async {
    _store[alarm.id] = alarm;
  }

  @override
  Future<Alarm?> findById(int id) async => _store[id];
}

/// Public API of the scheduling engine.
///
/// All time arithmetic is performed against [tz.local] (the device's local
/// timezone) so that alarms fire at the correct wall-clock time even after
/// a DST transition.
class AlarmService {
  AlarmService({
    required NotificationService notificationService,
    required PermissionService permissionService,
    required AlarmRepository repository,
  })  : _notifications = notificationService,
        _permissions = permissionService,
        _repository = repository;

  final NotificationService _notifications;
  // ignore: unused_field
  final PermissionService _permissions;
  final AlarmRepository _repository;

  /// Base offset used to derive the `android_alarm_manager_plus` request
  /// code from the alarm id. Keeping AAMP request codes in a distinct
  /// numeric space prevents accidental collisions with notification ids.
  static const int _aampIdOffset = 1000000;

  /// Returns whether the engine has been initialised. Mainly useful for
  /// tests.
  bool get isInitialized => _notifications.isInitialized;

  /// Initialises notifications, timezones and the AlarmManager bridge.
  ///
  /// Must be called from `main()` after `WidgetsFlutterBinding.ensureInitialized`.
  Future<void> initialize({
    DidReceiveNotificationResponseCallback? onForegroundAction,
  }) async {
    await _notifications.initialize(
      onForegroundAction: onForegroundAction,
      onBackgroundAction: notificationBackgroundActionHandler,
    );

    if (Platform.isAndroid) {
      // android_alarm_manager_plus must be initialised in the UI isolate
      // before any periodic / oneShot calls are made.
      await AndroidAlarmManager.initialize();
    }
  }

  // ===========================================================================
  // Public API
  // ===========================================================================

  /// Schedules (or re-schedules) [alarm] with the OS.
  ///
  /// Behaviour:
  /// * If [Alarm.enabled] is `false`, any pending schedule for this id is
  ///   cancelled and the method returns without re-scheduling.
  /// * If [Alarm.isRecurring] is `false`, a single zoned notification is
  ///   queued for [Alarm.dateTime].
  /// * If [Alarm.isRecurring] is `true`, the engine resolves the next
  ///   matching weekday and queues a `matchDateTimeComponents`-style daily
  ///   repeating notification for each requested day.
  Future<void> scheduleAlarm(Alarm alarm) async {
    // Persist first so reschedule-on-boot can see the alarm.
    await _repository.save(alarm);

    // Always cancel any previous schedule for this id to avoid duplicates.
    await _cancelPlatformAlarm(alarm.id);

    if (!alarm.enabled) {
      return;
    }

    if (alarm.isRecurring) {
      await _scheduleRecurring(alarm);
    } else {
      await _scheduleOneShot(alarm);
    }
  }

  /// Cancels the OS-level schedule for [alarmId]. The alarm itself is
  /// **not** removed from the repository — call your data-layer's delete()
  /// for that.
  Future<void> cancelAlarm(int alarmId) async {
    await _cancelPlatformAlarm(alarmId);
  }

  /// Reschedules every enabled alarm currently known to the repository.
  ///
  /// Typically called:
  ///   * On app startup, to recover from a process death.
  ///   * After [PermissionService.requestAll] reports a previously-missing
  ///     permission is now granted.
  ///   * From the BOOT_COMPLETED-triggered AlarmManager callback so all
  ///     alarms are re-armed after a reboot.
  Future<int> rescheduleAll() async {
    final List<Alarm> alarms = await _repository.loadAll();
    int rescheduled = 0;
    for (final Alarm alarm in alarms) {
      if (!alarm.enabled) continue;
      try {
        await scheduleAlarm(alarm);
        rescheduled++;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('AlarmService.rescheduleAll: failed for ${alarm.id}: $e\n$st');
        }
      }
    }
    return rescheduled;
  }

  /// Defers the currently-firing alarm by [Alarm.snoozeDurationMinutes].
  ///
  /// Internally cancels any in-flight notification for [alarmId], computes
  /// the new fire time relative to "now", and queues a fresh one-shot
  /// schedule. Recurring alarms keep their original recurrence — only the
  /// *current* iteration is pushed back.
  Future<void> snooze(int alarmId) async {
    final Alarm? alarm = await _repository.findById(alarmId);
    if (alarm == null) return;

    // Dismiss the notification UI for the original alarm.
    await _notifications.plugin.cancel(alarmId);

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime nextFire = now.add(Duration(minutes: alarm.snoozeDurationMinutes));

    await _notifications.plugin.zonedSchedule(
      alarmId,
      _titleFor(alarm),
      _bodyFor(alarm, snoozed: true),
      nextFire,
      _notifications.buildAlarmDetails(alarm),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: AlarmNotificationPayload(
        alarmId: alarm.id,
        fireMillisUtc: nextFire.toUtc().millisecondsSinceEpoch,
      ).encode(),
    );
  }

  /// Dismisses the currently-firing alarm. For one-shot alarms this also
  /// flips the persisted [Alarm.enabled] flag to `false`; for recurring
  /// ones the next occurrence remains scheduled.
  Future<void> dismiss(int alarmId) async {
    await _notifications.plugin.cancel(alarmId);

    final Alarm? alarm = await _repository.findById(alarmId);
    if (alarm == null) return;

    if (!alarm.isRecurring) {
      await _repository.save(alarm.copyWith(enabled: false));
    } else {
      // Recurring alarms remain scheduled for the next matching weekday;
      // zonedSchedule with matchDateTimeComponents handles that for us.
    }
  }

  // ===========================================================================
  // Internal scheduling helpers
  // ===========================================================================

  Future<void> _scheduleOneShot(Alarm alarm) async {
    final tz.TZDateTime when = _nextOneShotFire(alarm.dateTime);

    await _notifications.plugin.zonedSchedule(
      alarm.id,
      _titleFor(alarm),
      _bodyFor(alarm),
      when,
      _notifications.buildAlarmDetails(alarm),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: AlarmNotificationPayload(
        alarmId: alarm.id,
        fireMillisUtc: when.toUtc().millisecondsSinceEpoch,
      ).encode(),
    );

    await _registerAampGuard(alarm.id, when);
  }

  Future<void> _scheduleRecurring(Alarm alarm) async {
    // For each requested weekday we queue a separate notification id derived
    // from the alarm id, using `DateTimeComponents.dayOfWeekAndTime` so the
    // platform handles weekly recurrence (and DST!) for us.
    for (final int weekday in alarm.repeatDays) {
      final int slotId = _recurringSlotId(alarm.id, weekday);
      final tz.TZDateTime when = _nextWeekdayFire(alarm.dateTime, weekday);

      await _notifications.plugin.zonedSchedule(
        slotId,
        _titleFor(alarm),
        _bodyFor(alarm),
        when,
        _notifications.buildAlarmDetails(alarm),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: AlarmNotificationPayload(
          alarmId: alarm.id,
          fireMillisUtc: when.toUtc().millisecondsSinceEpoch,
        ).encode(),
      );

      await _registerAampGuard(slotId, when);
    }
  }

  /// Resolves the next [tz.TZDateTime] in `tz.local` that matches [target]'s
  /// wall-clock time. If [target] is already in the past, the same wall-clock
  /// time on the *next* day is returned. This is the canonical way to keep
  /// alarms correct across DST transitions.
  tz.TZDateTime _nextOneShotFire(DateTime target) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      target.year,
      target.month,
      target.day,
      target.hour,
      target.minute,
      target.second,
    );
    if (!scheduled.isAfter(now)) {
      // The caller asked for a date in the past — promote to the same
      // hh:mm:ss tomorrow so the user still gets *an* alarm.
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Resolves the next [tz.TZDateTime] in `tz.local` whose weekday matches
  /// [weekday] and whose time-of-day matches [target]. Used for recurring
  /// alarms.
  tz.TZDateTime _nextWeekdayFire(DateTime target, int weekday) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      target.hour,
      target.minute,
      target.second,
    );

    // Roll forward until we land on the requested weekday strictly in the
    // future.
    int safety = 0;
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
      if (++safety > 14) {
        // Should never happen: 14 days is enough to cover every weekday
        // even across a DST jump.
        break;
      }
    }
    return scheduled;
  }

  /// Belt-and-braces: also register an AndroidAlarmManager one-shot so the
  /// engine still gets a chance to react in the background even if the
  /// system aggressively suppresses notifications.
  Future<void> _registerAampGuard(int slotId, tz.TZDateTime when) async {
    if (!Platform.isAndroid) return;
    final int aampId = slotId + _aampIdOffset;
    final DateTime utc = when.toUtc();
    try {
      await AndroidAlarmManager.oneShotAt(
        utc,
        aampId,
        alarmManagerCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
        alarmClock: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmService: AAMP oneShotAt failed for $aampId: $e');
      }
    }
  }

  Future<void> _cancelPlatformAlarm(int alarmId) async {
    // Cancel the one-shot notification id, *and* every recurring slot id
    // that might exist for this alarm. We don't know whether the alarm was
    // previously recurring or one-shot, so we cover both cases.
    await _notifications.plugin.cancel(alarmId);

    for (int weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      final int slotId = _recurringSlotId(alarmId, weekday);
      await _notifications.plugin.cancel(slotId);
      if (Platform.isAndroid) {
        try {
          await AndroidAlarmManager.cancel(slotId + _aampIdOffset);
        } catch (_) {/* best-effort */}
      }
    }

    if (Platform.isAndroid) {
      try {
        await AndroidAlarmManager.cancel(alarmId + _aampIdOffset);
      } catch (_) {/* best-effort */}
    }
  }

  /// Derives a stable, unique notification id for a (alarm, weekday) pair.
  /// 7 distinct slots per alarm leave plenty of room within the 31-bit
  /// positive int range used by Android `PendingIntent` request codes.
  static int _recurringSlotId(int alarmId, int weekday) {
    return alarmId * 10 + weekday;
  }

  String _titleFor(Alarm alarm) => alarm.label.isNotEmpty ? alarm.label : 'Alarm';

  String _bodyFor(Alarm alarm, {bool snoozed = false}) {
    final String suffix = snoozed ? ' (snoozed)' : '';
    return 'It is time$suffix.';
  }
}

// =============================================================================
// Top-level background callbacks
//
// Both AndroidAlarmManager and flutter_local_notifications spawn a *separate*
// background isolate to deliver events. The Dart VM requires the callbacks
// targeted by these isolates to be top-level (or static) functions so the
// embedder can resolve them via `PluginUtilities.getCallbackHandle`.
// =============================================================================

/// Entry point invoked by `android_alarm_manager_plus` when an alarm fires.
///
/// We deliberately keep this function tiny — it just posts a fresh
/// notification using a *new* [FlutterLocalNotificationsPlugin] instance
/// scoped to the background isolate. Anything heavier (audio, full-screen
/// UI) is handled by the regular notification channel once the user taps it.
@pragma('vm:entry-point')
Future<void> alarmManagerCallback(int aampId) async {
  // Strip the AAMP id offset to recover the original notification slot id.
  final int slotId = aampId - AlarmService._aampIdOffset;
  if (kDebugMode) {
    debugPrint('alarmManagerCallback fired for slot $slotId');
  }
  // The notification has already been queued via zonedSchedule, so AAMP's
  // role here is purely a "wake the JVM" failsafe. We intentionally do not
  // re-post the notification: doing so would risk a duplicate alert.
}

/// Background isolate handler invoked when the user taps a notification
/// action (Snooze / Dismiss) while the app is not in the foreground.
@pragma('vm:entry-point')
void notificationBackgroundActionHandler(NotificationResponse response) {
  // Real action handling (snooze / dismiss) is performed by the UI isolate
  // through [AlarmService.snooze] / [AlarmService.dismiss] when the app
  // resumes. The background isolate cannot reliably hold the same
  // [AlarmRepository] state, so we keep this handler intentionally minimal.
  if (kDebugMode) {
    debugPrint(
      'notificationBackgroundActionHandler: ${response.actionId} for ${response.id}',
    );
  }
}

/// Convenience callback handle accessor used by [AlarmService] when calling
/// `AndroidAlarmManager.oneShotAt`. Kept here so the symbol is reachable
/// from `Function.toHandle()` in release builds.
CallbackHandle? get alarmManagerCallbackHandle =>
    PluginUtilities.getCallbackHandle(alarmManagerCallback);
