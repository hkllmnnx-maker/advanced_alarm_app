import 'package:flutter/material.dart';

import 'data/models/alarm.dart';
import 'data/models/dismiss_method.dart';
import 'ringing/ringing.dart';

/// Lightweight entry point used until the main app (Agent-04 / Agent-05)
/// is wired into `main`. It exists primarily to:
///
///  * Let `feat/ringing-screen` be compiled and analyzed in isolation.
///  * Provide a developer-facing demo launcher so the ringing screen can
///    be exercised end-to-end without needing the scheduling engine.
///
/// When `feat/alarm-engine` and `feat/ui-home` land on `main`, this file
/// will be replaced by their wired-up entry point; the ringing layer
/// will still be invoked via [RingingScreen.route].
void main() {
  runApp(const AdvancedAlarmApp());
}

class AdvancedAlarmApp extends StatelessWidget {
  const AdvancedAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6F00),
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      home: const _RingingDemoHome(),
    );
  }
}

/// Dev-only home that lets you launch the ringing screen with each
/// dismiss method, so you can manually verify the full UX:
///   * straight tap-to-dismiss,
///   * math puzzle challenge,
///   * shake-to-dismiss challenge.
class _RingingDemoHome extends StatelessWidget {
  const _RingingDemoHome();

  Future<void> _launch(BuildContext context, DismissMethod method) async {
    final Alarm alarm = Alarm(
      id: 'demo-${method.name}',
      label: 'Wake up!',
      hour: TimeOfDay.now().hour,
      minute: TimeOfDay.now().minute,
      dismissMethod: method,
    );
    final RingingResult? result = await Navigator.of(context).push(
      RingingScreen.route(RingingPayload(alarm: alarm)),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ringing ended: ${result?.name ?? 'unknown'}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringing screen — demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 8),
            Text(
              'feat/ringing-screen (Agent-06)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pick a dismiss method to launch the full-screen ringing '
              'experience. Use this to manually verify audio, vibration, '
              'wakelock, math puzzle and shake-to-dismiss.',
            ),
            const SizedBox(height: 32),
            FilledButton.tonalIcon(
              onPressed: () => _launch(context, DismissMethod.tap),
              icon: const Icon(Icons.touch_app),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Tap to dismiss'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _launch(context, DismissMethod.mathPuzzle),
              icon: const Icon(Icons.calculate),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Math puzzle to dismiss'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _launch(context, DismissMethod.shake),
              icon: const Icon(Icons.vibration),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Shake to dismiss'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
