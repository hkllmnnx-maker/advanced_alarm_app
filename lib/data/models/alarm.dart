import 'package:hive/hive.dart';

import 'dismiss_method.dart';
import 'weekday.dart';

/// Immutable domain model representing a single alarm.
///
/// Persisted to disk via [AlarmAdapter] (Hive [TypeAdapter]).
///
/// Designed to capture everything a professional alarm needs:
///  * [id]                  – stable unique identifier (UUID-like string).
///  * [label]               – user-facing label, e.g. "Morning workout".
///  * [hour] / [minute]     – local time-of-day (0–23, 0–59).
///  * [repeatDays]          – set of weekdays the alarm fires on; empty = one-shot.
///  * [ringtonePath]        – absolute path or asset id of the sound to play.
///  * [vibrate]             – whether vibration is enabled.
///  * [snoozeDurationMinutes] – minutes between snoozes (>= 0).
///  * [snoozeCount]         – maximum number of snoozes allowed (>= 0).
///  * [gradualVolumeIncrease] – fade-in volume over time.
///  * [isEnabled]           – on/off toggle.
///  * [createdAt] / [updatedAt] – audit timestamps.
///  * [dismissMethod]       – how the user must dismiss the alarm.
class Alarm {
  Alarm({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    Set<Weekday>? repeatDays,
    this.ringtonePath = '',
    this.vibrate = true,
    this.snoozeDurationMinutes = 5,
    this.snoozeCount = 3,
    this.gradualVolumeIncrease = true,
    this.isEnabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.dismissMethod = DismissMethod.tap,
  }) : assert(hour >= 0 && hour <= 23, 'hour must be in 0..23'),
       assert(minute >= 0 && minute <= 59, 'minute must be in 0..59'),
       assert(snoozeDurationMinutes >= 0, 'snoozeDurationMinutes must be >= 0'),
       assert(snoozeCount >= 0, 'snoozeCount must be >= 0'),
       repeatDays = repeatDays == null
           ? <Weekday>{}
           : Set<Weekday>.unmodifiable(repeatDays),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  final String label;
  final int hour;
  final int minute;
  final Set<Weekday> repeatDays;
  final String ringtonePath;
  final bool vibrate;
  final int snoozeDurationMinutes;
  final int snoozeCount;
  final bool gradualVolumeIncrease;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DismissMethod dismissMethod;

  /// True when the alarm should repeat on a weekly basis.
  bool get isRepeating => repeatDays.isNotEmpty;

  /// Returns a new [Alarm] with the given fields replaced.
  ///
  /// [updatedAt] defaults to `DateTime.now()` so callers don't have to
  /// remember to bump it. Pass an explicit value (including `null` via
  /// [keepUpdatedAt]) when you want to preserve the original timestamp,
  /// e.g. inside the repository when reading from disk.
  Alarm copyWith({
    String? label,
    int? hour,
    int? minute,
    Set<Weekday>? repeatDays,
    String? ringtonePath,
    bool? vibrate,
    int? snoozeDurationMinutes,
    int? snoozeCount,
    bool? gradualVolumeIncrease,
    bool? isEnabled,
    DateTime? updatedAt,
    DismissMethod? dismissMethod,
    bool keepUpdatedAt = false,
  }) {
    return Alarm(
      id: id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? this.repeatDays,
      ringtonePath: ringtonePath ?? this.ringtonePath,
      vibrate: vibrate ?? this.vibrate,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      gradualVolumeIncrease:
          gradualVolumeIncrease ?? this.gradualVolumeIncrease,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt,
      updatedAt: keepUpdatedAt ? this.updatedAt : (updatedAt ?? DateTime.now()),
      dismissMethod: dismissMethod ?? this.dismissMethod,
    );
  }

  /// JSON-style map representation. Useful for logging / debugging /
  /// future cloud-sync layers, and used internally as a stable disk
  /// shape by [AlarmAdapter].
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'hour': hour,
      'minute': minute,
      'repeatDays': repeatDays.map((Weekday d) => d.value).toList(),
      'ringtonePath': ringtonePath,
      'vibrate': vibrate,
      'snoozeDurationMinutes': snoozeDurationMinutes,
      'snoozeCount': snoozeCount,
      'gradualVolumeIncrease': gradualVolumeIncrease,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
      'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
      'dismissMethod': dismissMethod.value,
    };
  }

  /// Safe deserialization from a [Map]. Unknown / missing / corrupted
  /// fields fall back to sensible defaults so we never crash on bad
  /// data written by a previous (or future) version of the app.
  factory Alarm.fromMap(Map<dynamic, dynamic> map) {
    final List<dynamic> rawDays =
        (map['repeatDays'] as List<dynamic>?) ?? const <dynamic>[];
    final Set<Weekday> days = <Weekday>{};
    for (final dynamic raw in rawDays) {
      final Weekday? d = Weekday.fromValue(
        raw is int ? raw : int.tryParse('$raw'),
      );
      if (d != null) days.add(d);
    }

    DateTime parseTs(dynamic value) {
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          value,
          isUtc: true,
        ).toLocal();
      }
      return DateTime.now();
    }

    return Alarm(
      id: (map['id'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      hour: (map['hour'] as int?)?.clamp(0, 23) ?? 0,
      minute: (map['minute'] as int?)?.clamp(0, 59) ?? 0,
      repeatDays: days,
      ringtonePath: (map['ringtonePath'] as String?) ?? '',
      vibrate: (map['vibrate'] as bool?) ?? true,
      snoozeDurationMinutes:
          (map['snoozeDurationMinutes'] as int?)?.clamp(0, 60) ?? 5,
      snoozeCount: (map['snoozeCount'] as int?)?.clamp(0, 20) ?? 3,
      gradualVolumeIncrease: (map['gradualVolumeIncrease'] as bool?) ?? true,
      isEnabled: (map['isEnabled'] as bool?) ?? true,
      createdAt: parseTs(map['createdAt']),
      updatedAt: parseTs(map['updatedAt']),
      dismissMethod: DismissMethod.fromValue(map['dismissMethod'] as int?),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Alarm &&
        other.id == id &&
        other.label == label &&
        other.hour == hour &&
        other.minute == minute &&
        _setEquals(other.repeatDays, repeatDays) &&
        other.ringtonePath == ringtonePath &&
        other.vibrate == vibrate &&
        other.snoozeDurationMinutes == snoozeDurationMinutes &&
        other.snoozeCount == snoozeCount &&
        other.gradualVolumeIncrease == gradualVolumeIncrease &&
        other.isEnabled == isEnabled &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.dismissMethod == dismissMethod;
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    hour,
    minute,
    Object.hashAllUnordered(repeatDays),
    ringtonePath,
    vibrate,
    snoozeDurationMinutes,
    snoozeCount,
    gradualVolumeIncrease,
    isEnabled,
    createdAt,
    updatedAt,
    dismissMethod,
  );

  @override
  String toString() {
    final String time =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return 'Alarm(id: $id, label: "$label", time: $time, '
        'enabled: $isEnabled, repeatDays: ${repeatDays.length}, '
        'dismiss: ${dismissMethod.name})';
  }
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final T item in a) {
    if (!b.contains(item)) return false;
  }
  return true;
}

/// Hive [TypeAdapter] for [Alarm].
///
/// We delegate to [Alarm.toMap] / [Alarm.fromMap] so the on-disk shape
/// is a stable, human-readable map – which also makes it trivial to
/// migrate or export later without any codegen.
class AlarmAdapter extends TypeAdapter<Alarm> {
  /// Unique typeId for Hive. Must never change once data exists on disk.
  @override
  final int typeId = 1;

  @override
  Alarm read(BinaryReader reader) {
    final Map<dynamic, dynamic> map = Map<dynamic, dynamic>.from(
      reader.readMap(),
    );
    return Alarm.fromMap(map);
  }

  @override
  void write(BinaryWriter writer, Alarm obj) {
    writer.writeMap(obj.toMap());
  }
}
