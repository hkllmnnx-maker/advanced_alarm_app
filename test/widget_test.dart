// Basic widget test for the Advanced Alarm App bootstrap scaffold.
//
// This test simply verifies that the [AdvancedAlarmApp] widget builds
// successfully and that the placeholder home screen renders the app title.

import 'package:flutter_test/flutter_test.dart';

import 'package:advanced_alarm_app/main.dart';

void main() {
  testWidgets('AdvancedAlarmApp boots and shows the app title',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AdvancedAlarmApp());
    await tester.pumpAndSettle();

    expect(find.text('Advanced Alarm App'), findsWidgets);
  });
}
