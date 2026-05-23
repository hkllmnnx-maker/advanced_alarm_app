// Basic smoke test for the Advanced Alarm App.
//
// We render [MyApp] in the "data layer unavailable" state so the widget
// tree doesn't try to open a Hive box (which requires a temp directory
// and async init). This keeps the smoke test fast and independent of
// the storage layer – the storage layer has its own dedicated tests
// under test/data/.

import 'package:advanced_alarm_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots and shows the data-layer status screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(dataLayerReady: false));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Advanced Alarm – Data Layer'), findsOneWidget);
    expect(find.text('Storage unavailable'), findsOneWidget);
  });
}
