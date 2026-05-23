import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/alarm.dart';

/// Thin wrapper around the Hive box that stores [Alarm] records.
///
/// Responsibilities:
///  * Initialize Hive once per app lifecycle (idempotent).
///  * Register the [AlarmAdapter] exactly once (Hive throws on duplicates).
///  * Open (or reopen) the alarms box and expose it to the repository.
///  * Provide a small, testable seam: tests can inject a fake box by
///    constructing the database with an already-open [Box] via
///    [AlarmDatabase.fromBox].
///
/// All public methods are safe to call multiple times. Errors during
/// initialization are surfaced as exceptions but logged in debug mode
/// so the app does not silently fail.
class AlarmDatabase {
  AlarmDatabase._();

  /// Default singleton instance used by the production app.
  static final AlarmDatabase instance = AlarmDatabase._();

  /// Visible for testing: build a database backed by an already-open box.
  /// The caller is responsible for closing the box.
  @visibleForTesting
  factory AlarmDatabase.fromBox(Box<Alarm> box) {
    final AlarmDatabase db = AlarmDatabase._();
    db._box = box;
    db._initialized = true;
    return db;
  }

  /// Name of the Hive box that stores alarms.
  static const String boxName = 'alarms_box_v1';

  Box<Alarm>? _box;
  bool _initialized = false;
  Future<void>? _initFuture;

  /// Whether [init] has completed successfully.
  bool get isInitialized => _initialized && _box != null && _box!.isOpen;

  /// Returns the opened box. Throws [StateError] when called before [init].
  Box<Alarm> get box {
    final Box<Alarm>? b = _box;
    if (b == null || !b.isOpen) {
      throw StateError(
        'AlarmDatabase has not been initialized. Call AlarmDatabase.instance.init() '
        'before accessing the alarms box (typically once in main()).',
      );
    }
    return b;
  }

  /// Initializes Hive and opens the alarms box. Safe to call multiple
  /// times – subsequent calls return the same in-flight future.
  ///
  /// Pass [subDir] to override the on-disk location – useful for tests.
  Future<void> init({String? subDir}) {
    if (isInitialized) return Future<void>.value();
    return _initFuture ??= _doInit(subDir: subDir);
  }

  Future<void> _doInit({String? subDir}) async {
    try {
      // Hive.initFlutter is idempotent for the same path, but we still
      // guard against double-initialization here so unit tests that use
      // Hive.init() (no Flutter binding) keep working.
      await Hive.initFlutter(subDir);

      _registerAdapterIfNeeded();

      // openBox is also idempotent: if the box is already open Hive
      // returns the existing instance.
      _box = await Hive.openBox<Alarm>(boxName);
      _initialized = true;
    } catch (error, stack) {
      _initFuture = null; // allow retry
      if (kDebugMode) {
        debugPrint('AlarmDatabase.init failed: $error\n$stack');
      }
      rethrow;
    }
  }

  /// Registers [AlarmAdapter] exactly once. Hive throws
  /// `HiveError: There is already a TypeAdapter for typeId X.` if you
  /// try to register the same typeId twice, which is a real problem in
  /// hot-reload and test environments.
  static void _registerAdapterIfNeeded() {
    if (!Hive.isAdapterRegistered(AlarmAdapter().typeId)) {
      Hive.registerAdapter(AlarmAdapter());
    }
  }

  /// Closes the underlying box. Mostly useful in tests and when the
  /// user logs out / wipes data. Safe to call when not initialized.
  Future<void> close() async {
    final Box<Alarm>? b = _box;
    _box = null;
    _initialized = false;
    _initFuture = null;
    if (b != null && b.isOpen) {
      await b.close();
    }
  }
}
