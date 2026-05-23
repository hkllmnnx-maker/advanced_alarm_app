// Basic smoke test for the Advanced Alarm App.
//
// We render [AdvancedAlarmApp] in the "data layer unavailable" state so
// the widget tree doesn't try to open a Hive box (which requires a temp
// directory and async init). This keeps the smoke test fast and
// independent of the storage layer – the storage layer has its own
// dedicated tests under test/data/.

import 'package:advanced_alarm_app/core/services/services.dart';
import 'package:advanced_alarm_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'App boots and shows the storage-unavailable fallback when '
    'the data layer failed to initialize',
    (WidgetTester tester) async {
      final FlutterLocalNotificationsPlugin plugin =
          FlutterLocalNotificationsPlugin();
      final NotificationService notifications =
          NotificationService(plugin: plugin);
      final PermissionService permissions = PermissionService(plugin);
      final AlarmService alarmService = AlarmService(
        notificationService: notifications,
        permissionService: permissions,
        repository: InMemoryAlarmRepository(),
      );

      await tester.pumpWidget(
        AdvancedAlarmApp(
          dataLayerReady: false,
          alarmService: alarmService,
          permissionService: permissions,
        ),
      );

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Storage unavailable'), findsOneWidget);
    },
  );
}
