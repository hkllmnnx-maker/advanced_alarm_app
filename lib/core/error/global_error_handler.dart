import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Centralized crash reporting / error logging entry point for the app.
///
/// The handler is intentionally dependency-free: it sinks errors to
/// `dart:developer`'s `log()` channel (which IDEs, `flutter logs` and
/// any future Crashlytics adapter can pick up) and never throws itself.
///
/// Wiring is done in [main]:
///
/// ```dart
/// GlobalErrorHandler.install();
/// runZonedGuarded(() async {
///   ...
/// }, GlobalErrorHandler.recordZoneError);
/// ```
///
/// Design goals:
///   * Never break the user experience — every error is swallowed safely.
///   * Always preserve the original stack trace for debugging.
///   * Be a no-op when called more than once (idempotent install).
///   * Stay test-friendly: a custom [reporter] can be injected.
class GlobalErrorHandler {
  GlobalErrorHandler._();

  /// Optional pluggable sink. Defaults to [_defaultReporter] which logs
  /// via `dart:developer`. Tests (and future Crashlytics integration)
  /// can override this to capture errors.
  static void Function(ErrorRecord record) reporter = _defaultReporter;

  static bool _installed = false;

  /// Installs the framework-level error hook. Safe to call multiple
  /// times — subsequent calls are no-ops.
  static void install() {
    if (_installed) return;
    _installed = true;

    // 1) Synchronous framework errors (build / layout / paint).
    final FlutterExceptionHandler? previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _safelyReport(
        details.exception,
        details.stack ?? StackTrace.current,
        context: details.context?.toDescription() ?? 'FlutterError.onError',
        library: details.library,
        silent: details.silent,
      );
      // Preserve any previously installed handler (e.g. test harness).
      if (previousOnError != null) {
        previousOnError(details);
      } else if (kDebugMode && !details.silent) {
        // In debug, also dump to the console for fast feedback.
        FlutterError.dumpErrorToConsole(details);
      }
    };

    // 2) Errors that escape the Flutter engine itself (very rare, but
    //    still worth catching — e.g. errors from platform callbacks).
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _safelyReport(error, stack, context: 'PlatformDispatcher.onError');
      // Returning true tells the engine we've handled the error.
      return true;
    };
  }

  /// Records an error that was caught manually (e.g. inside a `try` /
  /// `catch` block or via [runZonedGuarded]). Never throws.
  static void recordError(
    Object error,
    StackTrace stackTrace, {
    String? context,
  }) {
    _safelyReport(error, stackTrace, context: context ?? 'recordError');
  }

  /// Convenience callback compatible with [runZonedGuarded]'s signature.
  static void recordZoneError(Object error, StackTrace stackTrace) {
    _safelyReport(error, stackTrace, context: 'runZonedGuarded');
  }

  /// Internal: forwards to the active [reporter], guarding against any
  /// exception thrown by the reporter itself.
  static void _safelyReport(
    Object error,
    StackTrace stackTrace, {
    required String context,
    String? library,
    bool silent = false,
  }) {
    try {
      reporter(
        ErrorRecord(
          error: error,
          stackTrace: stackTrace,
          context: context,
          library: library,
          silent: silent,
        ),
      );
    } catch (_) {
      // Never let the reporter itself crash the app.
    }
  }

  /// Resets the handler to its default state. Intended for tests only.
  @visibleForTesting
  static void resetForTesting() {
    _installed = false;
    reporter = _defaultReporter;
    FlutterError.onError = FlutterError.presentError;
    PlatformDispatcher.instance.onError = null;
  }
}

/// Default sink: pipes to `dart:developer.log()` so that IDEs and
/// `flutter logs` pick the events up. Logs are silenced in release
/// builds for "silent" framework errors (e.g. layout warnings during
/// hot reload) to keep the user console clean.
void _defaultReporter(ErrorRecord record) {
  if (record.silent && kReleaseMode) return;

  developer.log(
    'Unhandled error: ${record.error}',
    name:
        'advanced_alarm_app${record.library != null ? '.${record.library}' : ''}',
    error: record.error,
    stackTrace: record.stackTrace,
  );

  // In debug builds, also push to debugPrint so it's obvious during
  // local development without opening DevTools.
  if (kDebugMode) {
    debugPrint('[${record.context}] ${record.error}\n${record.stackTrace}');
  }
}

/// Lightweight value-object describing a single error event.
///
/// Public so that custom reporters (e.g. Crashlytics adapter, test
/// spies) can introspect the captured fields.
@immutable
class ErrorRecord {
  const ErrorRecord({
    required this.error,
    required this.stackTrace,
    required this.context,
    this.library,
    this.silent = false,
  });

  final Object error;
  final StackTrace stackTrace;
  final String context;
  final String? library;
  final bool silent;

  @override
  String toString() =>
      'ErrorRecord(context: $context, library: $library, error: $error)';
}
