import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/constants/app_constants.dart';
import 'core/services/services.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

/// Entry point of the Advanced Alarm App.
///
/// Bootstraps the alarm scheduling engine (notifications, timezones,
/// AndroidAlarmManager) **before** running the UI so that any alarms that
/// should have already fired can be replayed by `rescheduleAll()`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bootstrap the alarm engine. We use an in-memory repository for now —
  // the upcoming `feat/data-layer` branch will replace it with a Hive-backed
  // implementation via the same [AlarmRepository] contract.
  final NotificationService notificationService = NotificationService();
  final PermissionService permissionService =
      PermissionService(notificationService.plugin);
  final AlarmRepository repository = InMemoryAlarmRepository();
  final AlarmService alarmService = AlarmService(
    notificationService: notificationService,
    permissionService: permissionService,
    repository: repository,
  );

  await alarmService.initialize(
    onForegroundAction: _onForegroundNotificationAction,
  );

  // Recover from a previous process death / reboot. Safe to call even when
  // the repository is empty.
  try {
    await alarmService.rescheduleAll();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('main: rescheduleAll failed at startup: $e\n$st');
    }
  }

  runApp(AdvancedAlarmApp(
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
    required this.alarmService,
    required this.permissionService,
  });

  final AlarmService alarmService;
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
