// Basic smoke test for the Advanced Alarm App.
//
// Builds the root widget with stub services (no real plugin calls happen
// because the [InMemoryAlarmRepository] is empty and the engine is not
// initialised inside the test harness) and verifies the placeholder home
// screen renders the app title. The data layer is explicitly disabled so
// the widget tree doesn't try to open a Hive box during the smoke test —
// the storage layer has its own dedicated tests under `test/data/`.

import 'package:advanced_alarm_app/core/services/services.dart';
import 'package:advanced_alarm_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdvancedAlarmApp boots and shows the app title',
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
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Advanced Alarm App'), findsWidgets);
  });
}
