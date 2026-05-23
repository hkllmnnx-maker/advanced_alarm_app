import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// Restrict the flutter_riverpod import surface to just [ProviderScope]
// so it doesn't clash with `package:provider`'s [Provider] /
// [ChangeNotifierProvider] which we use for the settings layer.
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/error/global_error_handler.dart';
import 'core/services/services.dart';
import 'data/database/alarm_database.dart';
import 'features/settings/data/alarms_reset_controller.dart';
import 'features/settings/providers/settings_provider.dart';
import 'l10n/app_localizations.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

/// Entry point of the Advanced Alarm App.
///
/// Bootstrap order:
/// 0. Global error handler — installed FIRST so any framework/platform
///    error that occurs during the bootstrap below is still captured
///    instead of silently crashing the process or producing a red
///    error screen for the end user (feat/qa-hardening).
/// 1. Flutter binding.
/// 2. User-facing settings (theme / locale persistence).
/// 3. Local persistence layer (Hive-backed alarm database). Failure is
///    tolerated and surfaced via [AdvancedAlarmApp.dataLayerReady] so the
///    app never shows a black screen.
/// 4. Alarm scheduling engine (notifications, timezones, AndroidAlarmManager).
/// 5. `rescheduleAll()` so any alarm that should have already fired can be
///    replayed across reboots / process death.
///
/// The full-screen ringing experience (`lib/ringing/`) is launched on
/// demand via [RingingScreen.route] when an alarm actually fires; it is
/// not part of normal app startup.
///
/// The whole startup is wrapped in [runZonedGuarded] so any uncaught
/// async exception is routed through [GlobalErrorHandler] instead of
/// silently crashing the isolate.
Future<void> main() async {
  // --- 0. Global error handling (feat/qa-hardening) -----------------------
  // Install the synchronous Flutter framework error hook as early as
  // possible — before any widgets, services or even WidgetsBinding are
  // created. This catches build/layout/paint errors that originate
  // inside the widget tree and forwards them to our logger.
  GlobalErrorHandler.install();

  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // --- 1. User-facing settings (Agent-07) ---------------------------
      // Loaded first so the UI can pick up the persisted theme + locale
      // on the very first frame (no "flash of English" on Arabic devices).
      final SettingsProvider settingsProvider = await SettingsProvider.create();

      // --- 2. Data layer ------------------------------------------------
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

      // --- 3. Alarm engine ---------------------------------------------
      // For now we wire the engine to its bundled [InMemoryAlarmRepository].
      // The Hive-backed [AlarmDatabase] above is already initialized so a
      // dedicated adapter can bridge the two without changing this bootstrap.
      final NotificationService notificationService = NotificationService();
      final PermissionService permissionService = PermissionService(
        notificationService.plugin,
      );
      final AlarmRepository engineRepository = InMemoryAlarmRepository();
      final AlarmService alarmService = AlarmService(
        notificationService: notificationService,
        permissionService: permissionService,
        repository: engineRepository,
      );

      try {
        await alarmService.initialize(
          onForegroundAction: _onForegroundNotificationAction,
        );
        await alarmService.rescheduleAll();
      } catch (error, stackTrace) {
        GlobalErrorHandler.recordError(
          error,
          stackTrace,
          context: 'AlarmService.bootstrap',
        );
      }

      runApp(
        // Provider tree (Agent-07 settings layer) wraps the Riverpod scope
        // so anything inside — including the alarm engine UI — can `watch`
        // theme / locale changes synchronously.
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
            // The "Reset all alarms" destructive action in the Settings
            // screen is wired through this controller. Until the data
            // layer exposes a dedicated reset hook we keep the no-op
            // binding so the UI stays testable.
            Provider<AlarmsResetController>.value(
              value: const NoopAlarmsResetController(),
            ),
          ],
          child: ProviderScope(
            child: AdvancedAlarmApp(
              dataLayerReady: dataLayerReady,
              alarmService: alarmService,
              permissionService: permissionService,
            ),
          ),
        ),
      );
    },
    (Object error, StackTrace stackTrace) {
      // Async error escape hatch (feat/qa-hardening): any uncaught error
      // inside the zone — including Future / Stream errors that nobody
      // awaited — ends up here instead of being silently swallowed.
      GlobalErrorHandler.recordError(
        error,
        stackTrace,
        context: 'runZonedGuarded',
      );
    },
  );
}

/// Foreground tap / action handler. Wired into the engine via
/// [AlarmService.initialize].
void _onForegroundNotificationAction(NotificationResponse response) {
  if (kDebugMode) {
    debugPrint(
      'foreground notification action: ${response.actionId} / id=${response.id}',
    );
  }
}

/// Root widget of the application.
///
/// Hooks up:
///   * Light + dark Material 3 themes (auto-switched by the system).
///   * The [HomeScreen] as the landing surface once the local data layer
///     is ready.
///   * A graceful fallback screen when the data layer failed to
///     initialize, so the app never shows a black screen.
///   * A release-only friendly [ErrorWidget] so users never see
///     Flutter's default red error box (feat/qa-hardening).
class AdvancedAlarmApp extends StatelessWidget {
  const AdvancedAlarmApp({
    super.key,
    this.dataLayerReady = true,
    required this.alarmService,
    required this.permissionService,
  });

  /// Set to `false` only when [AlarmDatabase.init] threw at startup.
  final bool dataLayerReady;

  /// Live alarm scheduling engine.
  final AlarmService alarmService;

  /// Permission gateway used by the engine and the UI.
  final PermissionService permissionService;

  @override
  Widget build(BuildContext context) {
    // Install the friendly ErrorWidget once per app lifetime — and only
    // outside of tests, because the Flutter test framework explicitly
    // forbids changing `ErrorWidget.builder` from within widget tests.
    _installFriendlyErrorWidget();

    // Watch only the slices that the root must rebuild for: theme + locale.
    // Using `select` keeps the rest of the tree from rebuilding when
    // unrelated settings (e.g. default snooze) change.
    final ThemeMode themeMode = context.select<SettingsProvider, ThemeMode>(
      (p) => p.themeMode,
    );
    final Locale locale = context.select<SettingsProvider, Locale>(
      (p) => p.locale,
    );

    return MaterialApp(
      onGenerateTitle: (BuildContext ctx) {
        // Fall back to AppConstants if the localization delegate hasn't
        // resolved yet (e.g. before the first frame, or in unit tests
        // that don't install the delegate).
        final AppLocalizations? l = Localizations.of<AppLocalizations>(
          ctx,
          AppLocalizations,
        );
        return l?.appTitle ?? AppConstants.appName;
      },
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
      ErrorWidget.builder = (FlutterErrorDetails _) =>
          const _FriendlyErrorView();
    }
  }
}

/// `true` when the current binary is the `flutter_test` runner. We
/// detect this without importing `flutter_test` so that production
/// builds don't depend on the test harness.
bool get _isTestEnvironment {
  // The test framework defines this binding before any widget runs.
  // Outside of tests, [WidgetsBinding.instance] is the
  // [WidgetsFlutterBinding]. We use a string check to avoid pulling
  // test packages into release.
  return WidgetsBinding.instance.runtimeType.toString().contains('TestWidgets');
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
                Icon(
                  Icons.error_outline_rounded,
                  color: scheme.error,
                  size: 64,
                ),
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
/// details and frighten end users (feat/qa-hardening).
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
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 56,
                ),
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
