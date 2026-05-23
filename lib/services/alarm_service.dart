import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/alarm.dart';

/// Public API exposed by the alarm scheduling service.
///
/// The concrete platform implementation (Android `AlarmManager`,
/// iOS `UNUserNotificationCenter`, …) is owned by another agent –
/// the UI / editor layer only ever sees this abstract contract so it
/// can be safely mocked in tests and unit-tested in isolation.
///
/// Every method is asynchronous because real platform scheduling
/// involves IPC, and is intentionally tolerant: implementations must
/// never throw for "alarm not found" or "already cancelled" – they
/// simply complete normally.
abstract class AlarmService {
  /// Schedules (or re-schedules) the given alarm with the OS.
  ///
  /// Should be called every time an alarm is created, edited or
  /// re-enabled. It is the implementation's responsibility to:
  ///   * cancel any previous pending trigger for [alarm.id], and
  ///   * register a new one for the next occurrence.
  Future<void> scheduleAlarm(Alarm alarm);

  /// Cancels any pending OS-level trigger for the given alarm id.
  /// No-op when the id is unknown.
  Future<void> cancelAlarm(String id);

  /// Cancels every pending alarm. Used by "factory reset" flows.
  Future<void> cancelAll();
}

/// Safe default implementation used while the real platform service
/// is being built by a separate agent.
///
/// It is fully functional – it never throws, never blocks, and
/// faithfully logs every call in debug mode – which lets the editor
/// UI be developed and tested end-to-end without a real scheduler.
///
/// In production the application composition root simply swaps this
/// for the real implementation (e.g. `PlatformAlarmService`) without
/// any changes to the UI layer.
class InMemoryAlarmService implements AlarmService {
  InMemoryAlarmService();

  /// Tracks the alarms we believe are currently scheduled. This is
  /// purely informational – useful for debugging and for early UI
  /// integration tests.
  final Set<String> _scheduled = <String>{};

  /// Read-only view of the currently scheduled alarm ids.
  Set<String> get scheduledIds => Set<String>.unmodifiable(_scheduled);

  @override
  Future<void> scheduleAlarm(Alarm alarm) async {
    if (alarm.id.trim().isEmpty) {
      // Never crash – just log and bail.
      _log('scheduleAlarm called with empty id, ignoring.');
      return;
    }
    _scheduled.add(alarm.id);
    _log(
      'scheduleAlarm(id=${alarm.id}, time=${alarm.hour}:${alarm.minute}, '
      'enabled=${alarm.isEnabled}, repeats=${alarm.repeatDays.length})',
    );
  }

  @override
  Future<void> cancelAlarm(String id) async {
    if (id.trim().isEmpty) return;
    _scheduled.remove(id);
    _log('cancelAlarm(id=$id)');
  }

  @override
  Future<void> cancelAll() async {
    final int count = _scheduled.length;
    _scheduled.clear();
    _log('cancelAll() removed $count scheduled alarm(s)');
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[InMemoryAlarmService] $message');
    }
  }
}

/// Ambient locator for the currently active [AlarmService] instance.
///
/// We keep this deliberately minimal (no DI framework) so the UI
/// layer can call `AlarmServiceLocator.instance` without taking a
/// hard dependency on the concrete platform service.
///
/// The composition root (`main.dart`) is responsible for assigning
/// the real implementation at startup via [AlarmServiceLocator.register].
class AlarmServiceLocator {
  AlarmServiceLocator._();

  static AlarmService _instance = InMemoryAlarmService();

  /// Returns the currently registered alarm service.
  /// Falls back to [InMemoryAlarmService] if nothing was registered –
  /// this guarantees the UI never sees a null service.
  static AlarmService get instance => _instance;

  /// Swap the active implementation. Safe to call at any time
  /// (e.g. in tests with `setUp` / `tearDown`).
  static void register(AlarmService service) {
    _instance = service;
  }

  /// Restore the default in-memory implementation. Mostly useful
  /// in tests to undo a previous [register] call.
  @visibleForTesting
  static void reset() {
    _instance = InMemoryAlarmService();
  }
}
