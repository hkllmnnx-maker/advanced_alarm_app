// Unit tests for [GlobalErrorHandler]. Verifies that:
//   * install() is idempotent.
//   * FlutterError.onError is wired and forwards through the reporter.
//   * recordError() and recordZoneError() forward as expected.
//   * A throwing reporter cannot crash the app.

import 'package:advanced_alarm_app/core/error/global_error_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlobalErrorHandler', () {
    setUp(() {
      GlobalErrorHandler.resetForTesting();
    });

    tearDown(() {
      GlobalErrorHandler.resetForTesting();
    });

    test('install() is idempotent and wires FlutterError.onError', () {
      final FlutterExceptionHandler? before = FlutterError.onError;
      GlobalErrorHandler.install();
      final FlutterExceptionHandler? after1 = FlutterError.onError;
      GlobalErrorHandler.install(); // second call must be a no-op
      final FlutterExceptionHandler? after2 = FlutterError.onError;

      expect(after1, isNot(before));
      expect(after2, same(after1));
    });

    test('recordError() forwards through the active reporter', () {
      final List<Object> captured = <Object>[];
      GlobalErrorHandler.reporter = (record) {
        captured.add(record);
      };

      final error = Exception('boom');
      GlobalErrorHandler.recordError(
        error,
        StackTrace.current,
        context: 'unit-test',
      );

      expect(captured, hasLength(1));
    });

    test('recordZoneError() forwards through the active reporter', () {
      final List<Object> captured = <Object>[];
      GlobalErrorHandler.reporter = (record) {
        captured.add(record);
      };

      GlobalErrorHandler.recordZoneError(
        StateError('zone error'),
        StackTrace.current,
      );

      expect(captured, hasLength(1));
    });

    test('FlutterError.onError pipeline forwards through reporter', () {
      final List<Object> captured = <Object>[];
      GlobalErrorHandler.reporter = (record) {
        captured.add(record);
      };

      // Snapshot the test framework's existing onError handler so we
      // can restore it (and prevent re-throw) after our assertion.
      final FlutterExceptionHandler? testFrameworkOnError =
          FlutterError.onError;

      // Suppress re-throwing for the duration of this test by clearing
      // the previous handler. install() chains onto the *current*
      // onError, so we need to clear it BEFORE installing.
      FlutterError.onError = null;
      GlobalErrorHandler.install();

      try {
        final details = FlutterErrorDetails(
          exception: Exception('simulated framework error'),
          stack: StackTrace.current,
          library: 'unit-test',
          silent: true,
        );
        FlutterError.onError?.call(details);
        expect(captured, isNotEmpty);
      } finally {
        // Restore the test framework's handler so subsequent tests
        // behave normally.
        FlutterError.onError = testFrameworkOnError;
      }
    });

    test('throwing reporter does not crash recordError()', () {
      GlobalErrorHandler.reporter = (_) {
        throw StateError('reporter intentionally throws');
      };

      // Must not throw.
      expect(
        () =>
            GlobalErrorHandler.recordError(Exception('x'), StackTrace.current),
        returnsNormally,
      );
    });
  });
}
