import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/services/services.dart';
import 'data/database/alarm_database.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

/// Entry point of the Advanced Alarm App.
///
/// Bootstrap order:
/// 1. Flutter binding.
/// 2. Local persistence layer (Hive-backed alarm database). Failure is
///    tolerated and surfaced via [AdvancedAlarmApp.dataLayerReady] so the
///    app never shows a black screen.
/// 3. Alarm scheduling engine (notifications, timezones, AndroidAlarmManager).
/// 4. `rescheduleAll()` so any alarm that should have already fired can be
///    replayed across reboots / process death.
///
/// The full-screen ringing experience (`lib/ringing/`) is launched on
/// demand via [RingingScreen.route] when an alarm actually fires; it is
/// not part of normal app startup.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- 1. Data layer -------------------------------------------------------
  bool dataLayerReady = true;
  try {
    await AlarmDatabase.instance.init();
  } catch (e, s) {
    dataLayerReady = false;
    if (kDebugMode) {
      debugPrint('Data layer failed to initialize: $e\n$s');
    }
  }

  // --- 2. Alarm engine -----------------------------------------------------
  // For now we wire the engine to its bundled [InMemoryAlarmRepository].
  // The Hive-backed [AlarmDatabase] above is already initialized so a
  // dedicated adapter (added in qa-hardening) can bridge the two without
  // changing this bootstrap.
  final NotificationService notificationService = NotificationService();
  final PermissionService permissionService =
      PermissionService(notificationService.plugin);
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
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('main: alarm engine bootstrap failed: $e\n$st');
    }
  }

  runApp(
    ProviderScope(
      child: AdvancedAlarmApp(
        dataLayerReady: dataLayerReady,
        alarmService: alarmService,
        permissionService: permissionService,
      ),
    ),
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
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home:
          dataLayerReady ? const HomeScreen() : const _StorageUnavailableView(),
    );
  }
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
