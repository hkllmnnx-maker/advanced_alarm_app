// ignore_for_file: public_member_api_docs

/// Domain-level [Alarm] model used by the scheduling engine.
///
/// This is a deliberately pure-Dart model with **no dependency on Hive,
/// JSON, or any persistence layer**. The upcoming `feat/data-layer` branch
/// is expected to introduce a persisted [Alarm] entity that maps onto this
/// contract — either by `extends`-ing it or by providing `toAlarm()` /
/// `fromAlarm()` adapters.
///
/// Every field that the [AlarmService] needs in order to (re)schedule an
/// alarm lives here. Anything else (labels, custom sounds, user notes, etc.)
/// is considered a persistence concern.
class Alarm {
  Alarm({
    required this.id,
    required this.dateTime,
    this.enabled = true,
    this.label = '',
    this.repeatDays = const <int>{},
    this.snoozeDurationMinutes = 5,
    this.soundPath,
    this.vibrate = true,
  }) : assert(id >= 0, 'Alarm id must be non-negative.'),
       assert(
         repeatDays.every(
           (int d) => d >= DateTime.monday && d <= DateTime.sunday,
         ),
         'repeatDays entries must be in the range 1..7 (DateTime.monday..sunday).',
       ),
       assert(
         snoozeDurationMinutes > 0,
         'snoozeDurationMinutes must be positive.',
       );

  /// Stable, unique identifier for this alarm.
  ///
  /// Used as the notification id, the AlarmManager request code, and the key
  /// in any persistence layer. Must fit in a 32-bit signed integer because
  /// Android `PendingIntent` request codes are `int` on the platform side.
  final int id;

  /// The next time at which this alarm should fire, expressed in **local
  /// wall-clock time**. The engine is responsible for converting this into
  /// the device's current timezone via the `timezone` package before
  /// handing it to the platform.
  final DateTime dateTime;

  /// Whether this alarm is currently active. Disabled alarms are not
  /// scheduled with the platform.
  final bool enabled;

  /// User-visible label shown in the notification (e.g. "Wake up").
  final String label;

  /// Days of the week on which the alarm should repeat, using
  /// [DateTime.monday] .. [DateTime.sunday] (1..7).
  ///
  /// * An **empty** set means a *one-shot* alarm (fires once on [dateTime]).
  /// * A **non-empty** set means a *recurring* alarm; [dateTime]'s time-of-day
  ///   is used as the fire time, while its date component is ignored.
  final Set<int> repeatDays;

  /// Snooze duration in minutes used by [AlarmService.snooze].
  final int snoozeDurationMinutes;

  /// Optional path / asset reference for a custom alarm sound. `null` means
  /// the system default alarm sound is used.
  final String? soundPath;

  /// Whether the device should vibrate when this alarm fires.
  final bool vibrate;

  /// Returns `true` when this is a recurring (weekly) alarm.
  bool get isRecurring => repeatDays.isNotEmpty;

  /// Convenience copy-with helper.
  Alarm copyWith({
    int? id,
    DateTime? dateTime,
    bool? enabled,
    String? label,
    Set<int>? repeatDays,
    int? snoozeDurationMinutes,
    String? soundPath,
    bool? vibrate,
  }) {
    return Alarm(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
      repeatDays: repeatDays ?? this.repeatDays,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      soundPath: soundPath ?? this.soundPath,
      vibrate: vibrate ?? this.vibrate,
    );
  }

  @override
  String toString() =>
      'Alarm(id: $id, dateTime: $dateTime, enabled: $enabled, '
      'label: "$label", repeatDays: $repeatDays, '
      'snoozeDurationMinutes: $snoozeDurationMinutes, vibrate: $vibrate)';
}
