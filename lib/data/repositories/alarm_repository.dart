import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../database/alarm_database.dart';
import '../models/alarm.dart';

/// Thrown when a repository operation fails. We never propagate raw
/// Hive errors to the UI layer – the message is always a human-readable
/// string and the original error is kept in [cause] for logging.
class AlarmRepositoryException implements Exception {
  AlarmRepositoryException(this.message, [this.cause, this.stackTrace]);

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() =>
      'AlarmRepositoryException: $message'
      '${cause == null ? '' : ' (cause: $cause)'}';
}

/// Clean, framework-agnostic repository for [Alarm] objects.
///
/// Backed by a Hive [Box] under the hood, but consumers only see a
/// minimal CRUD + reactive surface so we can swap storage (Isar, SQLite,
/// remote, ...) later without touching the rest of the app.
///
/// All methods are defensive:
///  * Inputs are validated before hitting the box.
///  * Unexpected box errors are wrapped in [AlarmRepositoryException].
///  * Corrupted records returned by the box are skipped instead of
///    propagating a crash.
///
/// Use [AlarmRepository.fromDatabase] in production, and inject a custom
/// [Box] via the default constructor in tests.
class AlarmRepository {
  AlarmRepository(this._box);

  /// Builds a repository from the shared [AlarmDatabase] singleton.
  /// The database MUST already be initialized via
  /// `AlarmDatabase.instance.init()` (typically inside `main()`).
  factory AlarmRepository.fromDatabase([AlarmDatabase? db]) {
    final AlarmDatabase database = db ?? AlarmDatabase.instance;
    return AlarmRepository(database.box);
  }

  final Box<Alarm> _box;

  // ---------------------------------------------------------------------------
  //  Reads
  // ---------------------------------------------------------------------------

  /// Returns all alarms currently stored, sorted by time-of-day (asc).
  /// Returns an empty list when the box is empty or fully corrupted.
  List<Alarm> getAll() {
    try {
      final List<Alarm> alarms = <Alarm>[];
      for (final dynamic raw in _box.values) {
        if (raw is Alarm) alarms.add(raw);
      }
      alarms.sort((Alarm a, Alarm b) {
        final int byHour = a.hour.compareTo(b.hour);
        if (byHour != 0) return byHour;
        return a.minute.compareTo(b.minute);
      });
      return alarms;
    } catch (e, s) {
      _logError('getAll', e, s);
      return <Alarm>[];
    }
  }

  /// Returns a single alarm by [id], or `null` when it does not exist.
  Alarm? getById(String id) {
    if (id.isEmpty) return null;
    try {
      final dynamic value = _box.get(id);
      return value is Alarm ? value : null;
    } catch (e, s) {
      _logError('getById($id)', e, s);
      return null;
    }
  }

  /// Convenience for the UI: only the alarms that are currently enabled.
  List<Alarm> getEnabled() =>
      getAll().where((Alarm a) => a.isEnabled).toList(growable: false);

  /// Total count of stored alarms. Always safe to call.
  int count() {
    try {
      return _box.length;
    } catch (e, s) {
      _logError('count', e, s);
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  //  Writes (CRUD)
  // ---------------------------------------------------------------------------

  /// Inserts a new alarm. Throws [AlarmRepositoryException] when an alarm
  /// with the same id already exists – use [upsert] when you don't care.
  Future<void> add(Alarm alarm) async {
    _validate(alarm);
    try {
      if (_box.containsKey(alarm.id)) {
        throw AlarmRepositoryException(
          'An alarm with id "${alarm.id}" already exists.',
        );
      }
      await _box.put(alarm.id, alarm);
    } on AlarmRepositoryException {
      rethrow;
    } catch (e, s) {
      _logError('add', e, s);
      throw AlarmRepositoryException('Failed to add alarm.', e, s);
    }
  }

  /// Updates an existing alarm. Throws when the id is unknown.
  ///
  /// Always bumps [Alarm.updatedAt] so the UI / sync layer can detect
  /// fresh changes. Pass an already-stamped alarm via [keepTimestamp]
  /// to keep the original [updatedAt] (used by tests).
  Future<void> update(Alarm alarm, {bool keepTimestamp = false}) async {
    _validate(alarm);
    try {
      if (!_box.containsKey(alarm.id)) {
        throw AlarmRepositoryException('No alarm found with id "${alarm.id}".');
      }
      final Alarm toStore = keepTimestamp
          ? alarm
          : alarm.copyWith(updatedAt: DateTime.now());
      await _box.put(alarm.id, toStore);
    } on AlarmRepositoryException {
      rethrow;
    } catch (e, s) {
      _logError('update', e, s);
      throw AlarmRepositoryException('Failed to update alarm.', e, s);
    }
  }

  /// Inserts or updates – whichever applies. Useful for sync / import.
  Future<void> upsert(Alarm alarm) async {
    _validate(alarm);
    try {
      await _box.put(alarm.id, alarm);
    } catch (e, s) {
      _logError('upsert', e, s);
      throw AlarmRepositoryException('Failed to save alarm.', e, s);
    }
  }

  /// Toggles the enabled flag for [id]. Returns the new value, or
  /// `null` when the alarm does not exist.
  Future<bool?> toggleEnabled(String id) async {
    final Alarm? current = getById(id);
    if (current == null) return null;
    final Alarm next = current.copyWith(isEnabled: !current.isEnabled);
    await update(next);
    return next.isEnabled;
  }

  /// Removes an alarm by id. Silently no-ops if it doesn't exist.
  Future<void> delete(String id) async {
    if (id.isEmpty) return;
    try {
      await _box.delete(id);
    } catch (e, s) {
      _logError('delete($id)', e, s);
      throw AlarmRepositoryException('Failed to delete alarm.', e, s);
    }
  }

  /// Removes every alarm. Useful for "factory reset" and tests.
  Future<void> clear() async {
    try {
      await _box.clear();
    } catch (e, s) {
      _logError('clear', e, s);
      throw AlarmRepositoryException('Failed to clear alarms.', e, s);
    }
  }

  // ---------------------------------------------------------------------------
  //  Reactive stream
  // ---------------------------------------------------------------------------

  /// A stream that emits the full, sorted list of alarms every time the
  /// underlying box changes (add / update / delete / clear).
  ///
  /// Emits the current snapshot synchronously upon subscription so the
  /// UI can render its initial state without an extra `getAll()` call.
  ///
  /// The stream completes when the box is closed.
  Stream<List<Alarm>> watchAll() {
    late StreamController<List<Alarm>> controller;
    StreamSubscription<BoxEvent>? sub;

    void emitSnapshot() {
      if (controller.isClosed) return;
      controller.add(getAll());
    }

    controller = StreamController<List<Alarm>>(
      onListen: () {
        emitSnapshot(); // initial state
        sub = _box.watch().listen(
          (_) => emitSnapshot(),
          onError: (Object e, StackTrace s) {
            _logError('watchAll', e, s);
            // Don't kill the stream on a single bad event – just keep going.
          },
          cancelOnError: false,
        );
      },
      onCancel: () async {
        await sub?.cancel();
        sub = null;
      },
    );

    return controller.stream;
  }

  /// Watch a single alarm by id. Emits `null` if it gets deleted.
  Stream<Alarm?> watchById(String id) {
    late StreamController<Alarm?> controller;
    StreamSubscription<BoxEvent>? sub;

    void emit() {
      if (controller.isClosed) return;
      controller.add(getById(id));
    }

    controller = StreamController<Alarm?>(
      onListen: () {
        emit();
        sub = _box
            .watch(key: id)
            .listen(
              (_) => emit(),
              onError: (Object e, StackTrace s) =>
                  _logError('watchById($id)', e, s),
              cancelOnError: false,
            );
      },
      onCancel: () async {
        await sub?.cancel();
        sub = null;
      },
    );

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  //  Internals
  // ---------------------------------------------------------------------------

  void _validate(Alarm alarm) {
    if (alarm.id.trim().isEmpty) {
      throw AlarmRepositoryException('Alarm id must not be empty.');
    }
    if (alarm.hour < 0 || alarm.hour > 23) {
      throw AlarmRepositoryException(
        'Alarm hour out of range: ${alarm.hour} (expected 0..23).',
      );
    }
    if (alarm.minute < 0 || alarm.minute > 59) {
      throw AlarmRepositoryException(
        'Alarm minute out of range: ${alarm.minute} (expected 0..59).',
      );
    }
    if (alarm.snoozeDurationMinutes < 0) {
      throw AlarmRepositoryException('snoozeDurationMinutes must be >= 0.');
    }
    if (alarm.snoozeCount < 0) {
      throw AlarmRepositoryException('snoozeCount must be >= 0.');
    }
  }

  void _logError(String operation, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('AlarmRepository.$operation failed: $error\n$stack');
    }
  }
}
