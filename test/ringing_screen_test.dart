import 'package:advanced_alarm_app/data/models/alarm.dart';
import 'package:advanced_alarm_app/data/models/dismiss_method.dart';
import 'package:advanced_alarm_app/ringing/audio/alarm_audio_player.dart';
import 'package:advanced_alarm_app/ringing/audio/alarm_vibrator.dart';
import 'package:advanced_alarm_app/ringing/ringing_controller.dart';
import 'package:advanced_alarm_app/ringing/ringing_payload.dart';
import 'package:advanced_alarm_app/ringing/ringing_screen.dart';
import 'package:advanced_alarm_app/ringing/services/shake_detector.dart';
import 'package:advanced_alarm_app/ringing/services/wakelock_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audio player that records calls but performs no real I/O — needed
/// because the `audioplayers` plugin's MethodChannel is unavailable in
/// the widget test environment.
class _NoOpAudioPlayer extends AlarmAudioPlayer {
  bool started = false;
  bool stopped = false;

  @override
  Future<void> start({
    required String ringtonePath,
    required bool gradualVolumeRise,
    double maxVolume = 1.0,
  }) async {
    started = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> dispose() async {
    stopped = true;
  }

  @override
  Future<void> boostToMax() async {}
}

class _NoOpVibrator extends AlarmVibrator {
  bool started = false;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _NoOpShake extends ShakeDetector {
  _NoOpShake() : super(shakesRequired: 3);

  @override
  void start({
    required VoidCallback onShakesComplete,
    ValueChanged<int>? onProgress,
  }) {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _NoOpWakelock extends WakelockGuard {
  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}

  @override
  Future<void> dispose() async {}
}

RingingController _testController(RingingPayload payload) {
  return RingingController(
    payload: payload,
    audioPlayer: _NoOpAudioPlayer(),
    vibrator: _NoOpVibrator(),
    shakeDetector: _NoOpShake(),
    wakelock: _NoOpWakelock(),
  );
}

/// Resize the test window to a typical portrait phone (Pixel 6 ≈
/// 411 × 914 logical px) so [Spacer] doesn't fight the layout in
/// the tiny default 800×600 test surface.
Future<void> _useTallSurface(WidgetTester tester) async {
  final TestWidgetsFlutterBinding binding = tester.binding;
  await binding.setSurfaceSize(const Size(411, 914));
  addTearDown(() => binding.setSurfaceSize(null));
}

void main() {
  group('RingingScreen', () {
    testWidgets('renders label, time digits and both action buttons', (
      WidgetTester tester,
    ) async {
      await _useTallSurface(tester);
      final Alarm alarm = Alarm(
        id: 'a1',
        label: 'Morning Run',
        hour: 6,
        minute: 30,
        dismissMethod: DismissMethod.tap,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RingingScreen(
            payload: RingingPayload(alarm: alarm),
            controllerFactory: _testController,
          ),
        ),
      );
      // First frame builds the static UI synchronously.
      await tester.pump();
      // Let the post-frame callback fire (which kicks off the
      // controller). We deliberately avoid `pumpAndSettle` because the
      // background pulse animation loops forever.
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('Morning Run'), findsOneWidget);
      expect(find.text('Snooze'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.byIcon(Icons.alarm), findsOneWidget);
      expect(find.byIcon(Icons.snooze), findsOneWidget);
      expect(find.byIcon(Icons.alarm_off), findsOneWidget);
    });

    testWidgets('tap-to-dismiss flow completes with RingingResult.dismissed', (
      WidgetTester tester,
    ) async {
      await _useTallSurface(tester);
      final Alarm alarm = Alarm(
        id: 'a2',
        label: 'Quick alarm',
        hour: 7,
        minute: 0,
        dismissMethod: DismissMethod.tap,
      );
      final RingingController controller = _testController(
        RingingPayload(alarm: alarm),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RingingScreen(
            payload: RingingPayload(alarm: alarm),
            controllerFactory: (_) => controller,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      await tester.tap(find.text('Dismiss'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final RingingResult result = await controller.done;
      expect(result, RingingResult.dismissed);
    });

    testWidgets('Snooze button finishes with RingingResult.snoozed', (
      WidgetTester tester,
    ) async {
      await _useTallSurface(tester);
      final Alarm alarm = Alarm(
        id: 'a3',
        label: 'Snoozy',
        hour: 8,
        minute: 15,
        dismissMethod: DismissMethod.tap,
      );
      final RingingController controller = _testController(
        RingingPayload(alarm: alarm),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RingingScreen(
            payload: RingingPayload(alarm: alarm),
            controllerFactory: (_) => controller,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      await tester.tap(find.text('Snooze'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(await controller.done, RingingResult.snoozed);
    });
  });
}
