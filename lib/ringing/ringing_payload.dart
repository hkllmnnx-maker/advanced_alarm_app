import 'package:flutter/foundation.dart';

import '../data/models/alarm.dart';
import '../data/models/dismiss_method.dart';

/// Immutable bundle of everything [RingingScreen] needs to render and
/// orchestrate a single firing alarm.
///
/// The ringing layer intentionally does **not** depend on the live
/// [AlarmRepository]: it receives all the data it needs at construction
/// time, so the same screen can be invoked from a notification tap, a
/// full-screen intent or a deep-link without coupling.
@immutable
class RingingPayload {
  RingingPayload({
    required this.alarm,
    DateTime? firedAt,
  }) : firedAt = firedAt ?? DateTime.now();

  /// Convenience factory: build a payload from raw fields. Useful for
  /// background isolates that may not have the full [Alarm] handy.
  factory RingingPayload.fromFields({
    required String alarmId,
    required String label,
    required int hour,
    required int minute,
    String ringtonePath = '',
    bool vibrate = true,
    bool gradualVolumeIncrease = true,
    int snoozeDurationMinutes = 5,
    int snoozeCount = 3,
    DismissMethod dismissMethod = DismissMethod.tap,
    DateTime? firedAt,
  }) {
    return RingingPayload(
      alarm: Alarm(
        id: alarmId,
        label: label,
        hour: hour,
        minute: minute,
        ringtonePath: ringtonePath,
        vibrate: vibrate,
        gradualVolumeIncrease: gradualVolumeIncrease,
        snoozeDurationMinutes: snoozeDurationMinutes,
        snoozeCount: snoozeCount,
        dismissMethod: dismissMethod,
      ),
      firedAt: firedAt,
    );
  }

  /// The alarm that is currently firing.
  final Alarm alarm;

  /// Wall-clock time at which the alarm started ringing. Used by the UI
  /// to show the current time and to compute "ringing for N seconds".
  final DateTime firedAt;

  @override
  String toString() => 'RingingPayload(alarm: ${alarm.id}, firedAt: $firedAt)';
}
