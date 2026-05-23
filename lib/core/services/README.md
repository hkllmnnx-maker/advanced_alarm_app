# Alarm Scheduling Engine

This package implements the reliable, OS-level alarm scheduling layer used
by the Advanced Alarm App. It is delivered by the `feat/alarm-engine` branch
and is the foundation every other feature (UI, data-layer, settings) builds
on top of.

## Public API surface

Everything goes through `AlarmService`:

```dart
final alarmService = AlarmService(
  notificationService: notifications,
  permissionService: permissions,
  repository: repository, // any AlarmRepository implementation
);

await alarmService.initialize();      // call once from main()
await alarmService.scheduleAlarm(alarm);
await alarmService.cancelAlarm(id);
await alarmService.rescheduleAll();   // call after boot / permission grant
await alarmService.snooze(id);
await alarmService.dismiss(id);
```

`AlarmService` only depends on the `Alarm` domain model
(`features/alarm/domain/alarm.dart`) and on an `AlarmRepository`. The
upcoming `feat/data-layer` branch will provide a Hive-backed
`AlarmRepository` and an `Alarm` entity that maps onto this contract — no
breaking changes are expected.

## Reliability guarantees

| Concern | How the engine handles it |
| ------- | ------------------------ |
| Exact firing time across DST | All schedules are anchored to `tz.TZDateTime` in `tz.local`, which the `timezone` package recalculates on every DST transition. |
| Device reboot | `flutter_local_notifications` registers its own `ScheduledNotificationBootReceiver`. AAMP one-shots are registered with `rescheduleOnReboot: true`. On startup we also call `AlarmService.rescheduleAll()`. |
| Doze mode | We use `AndroidScheduleMode.exactAllowWhileIdle` for notifications and `allowWhileIdle: true, alarmClock: true` for AAMP one-shots. |
| Android 12+ exact alarms | `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM` declared in the manifest, and `PermissionService.requestAll()` opens the settings screen if revoked. |
| Android 13+ notifications | `POST_NOTIFICATIONS` declared and requested at runtime. |
| Android 14+ full-screen intent | `USE_FULL_SCREEN_INTENT` declared and requested. The launcher activity has `showWhenLocked` + `turnScreenOn` so it can take over the lock screen. |
| Battery optimizations | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` + `Permission.ignoreBatteryOptimizations.request()` opens the system whitelist screen. |
| iOS background firing | Background modes (`audio`, `fetch`, `processing`, `remote-notification`) declared in `Info.plist`; notifications use `InterruptionLevel.timeSensitive`. |

## Internal layout

```
core/services/
├── alarm_service.dart         # public AlarmService API + repository contract
├── notification_service.dart  # FlutterLocalNotificationsPlugin wrapper + channel
├── permission_service.dart    # runtime permission orchestration
└── services.dart              # barrel export
```

The background isolate entry points (`alarmManagerCallback`,
`notificationBackgroundActionHandler`) are top-level functions annotated
with `@pragma('vm:entry-point')` so they survive tree shaking in release
builds.
