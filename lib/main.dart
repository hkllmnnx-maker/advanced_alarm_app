import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/error/global_error_handler.dart';
import 'data/data.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

/// Application entry point.
///
/// Wires up the global error handler **before** any Flutter/Dart code is
/// allowed to throw, then boots the local data layer and finally hands
/// control to [AdvancedAlarmApp]. The whole startup is wrapped in
/// [runZonedGuarded] so that *any* unhandled async exception is captured
/// and logged through [GlobalErrorHandler] instead of crashing the app
/// or producing a red error screen for the end user.
Future<void> main() async {
  // Install the synchronous Flutter framework error hook as early as
  // possible. This catches build/layout/paint errors that originate
  // inside the widget tree and forwards them to our logger.
  GlobalErrorHandler.install();

  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Safely initialize the local data layer before the UI starts. If
      // the database fails to come up (e.g. corrupted box on disk) we
      // still want the app to launch in a degraded state instead of
      // crashing on a black screen.
      bool dataLayerReady = true;
      try {
        await AlarmDatabase.instance.init();
      } catch (error, stackTrace) {
        dataLayerReady = false;
        GlobalErrorHandler.recordError(
          error,
          stackTrace,
          context: 'AlarmDatabase.init',
        );
      }

      runApp(
        ProviderScope(
          child: AdvancedAlarmApp(dataLayerReady: dataLayerReady),
        ),
      );
    },
    (Object error, StackTrace stackTrace) {
      // Async error escape hatch: any uncaught error inside the zone
      // (including Future / Stream errors) ends up here.
      GlobalErrorHandler.recordError(
        error,
        stackTrace,
        context: 'runZonedGuarded',
      );
    },
  );
}

/// Root widget of the application.
///
/// Hooks up:
///   * Light + dark Material 3 themes (auto-switched by the system).
///   * The [HomeScreen] as the landing surface once the local data
///     layer is ready.
///   * A graceful fallback screen when the data layer failed to
///     initialize, so the app never shows a black screen.
class AdvancedAlarmApp extends StatelessWidget {
  const AdvancedAlarmApp({super.key, this.dataLayerReady = true});

  /// Set to `false` only when [AlarmDatabase.init] threw at startup.
  final bool dataLayerReady;

  @override
  Widget build(BuildContext context) {
    // Install the friendly ErrorWidget once per app lifetime — and only
    // outside of tests, because the Flutter test framework explicitly
    // forbids changing `ErrorWidget.builder` from within widget tests.
    _installFriendlyErrorWidget();

    return MaterialApp(
      title: 'Advanced Alarm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: dataLayerReady
          ? const HomeScreen()
          : const _StorageUnavailableView(),
    );
  }

  static bool _errorWidgetInstalled = false;

  static void _installFriendlyErrorWidget() {
    if (_errorWidgetInstalled) return;
    // Never override Flutter's default ErrorWidget while running tests
    // — the test framework asserts on the field's identity.
    if (_isTestEnvironment) return;
    _errorWidgetInstalled = true;

    // In debug builds keep Flutter's red screen so developers see the
    // stack trace right away; in release builds show a friendly view.
    if (!kDebugMode) {
      ErrorWidget.builder =
          (FlutterErrorDetails _) => const _FriendlyErrorView();
    }
  }
}

/// `true` when the current binary is the `flutter_test` runner. We
/// detect this without importing `flutter_test` so that production
/// builds don't depend on the test harness.
bool get _isTestEnvironment {
  // The test framework defines this binding before any widget runs.
  // Outside of tests, [WidgetsBinding.instance] is the
  // [WidgetsFlutterBinding].
  // We use a string check to avoid pulling test packages into release.
  return WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgets');
}

/// Shown when the local Hive box could not be opened. The app stays
/// usable enough to display the error and a help message, but no alarms
/// can be persisted in this state.
class _StorageUnavailableView extends StatelessWidget {
  const _StorageUnavailableView();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Alarm')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.error_outline_rounded,
                    color: scheme.error, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Storage unavailable',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The local alarm database failed to initialize. '
                  'Please restart the app. If the issue persists, '
                  'clearing the app storage will recover it.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// User-friendly fallback widget shown in release builds whenever a
/// widget subtree throws during build/layout/paint. Replaces Flutter's
/// default red [ErrorWidget] which would otherwise leak technical
/// details and frighten end users.
class _FriendlyErrorView extends StatelessWidget {
  const _FriendlyErrorView();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B1B1F),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                Icon(Icons.warning_amber_rounded,
                    color: Colors.amber, size: 56),
                SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'The screen could not be displayed. '
                  'Please go back and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
