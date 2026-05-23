import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/constants/app_constants.dart';
import 'core/services/services.dart';
import 'core/theme/app_theme.dart';
import 'data/database/alarm_database.dart';
import 'features/home/home_screen.dart';

/// Entry point of the Advanced Alarm App.
///
/// Bootstrap order:
/// 1. Flutter binding.
/// 2. Local persistence layer (Hive-backed alarm database). Failure is
///    tolerated and surfaced via [AdvancedAlarmApp.dataLayerReady] instead
///    of crashing the process.
/// 3. Alarm scheduling engine (notifications, timezones, AndroidAlarmManager).
/// 4. `rescheduleAll()` so any alarm that should have already fired can be
///    replayed across reboots / process death.
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
  // The Hive-backed [AlarmDatabase] above is already initialized so future
  // branches can plug it into the engine via an adapter without changing
  // this bootstrap.
  final NotificationService notificationService = NotificationService();
  final PermissionService permissionService =
      PermissionService(notificationService.plugin);
  final AlarmRepository repository = InMemoryAlarmRepository();
  final AlarmService alarmService = AlarmService(
    notificationService: notificationService,
    permissionService: permissionService,
    repository: repository,
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

  runApp(AdvancedAlarmApp(
    dataLayerReady: dataLayerReady,
    alarmService: alarmService,
    permissionService: permissionService,
  ));
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

/// Root [MaterialApp] of the project.
class AdvancedAlarmApp extends StatelessWidget {
  const AdvancedAlarmApp({
    super.key,
    this.dataLayerReady = true,
    required this.alarmService,
    required this.permissionService,
  });

  /// Whether the local persistence layer started up successfully.
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
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
