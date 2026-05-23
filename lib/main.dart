import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/data.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely initialize the local data layer before the UI starts. If the
  // database fails to come up (e.g. corrupted box on disk) we still want
  // the app to launch in a degraded state instead of crashing on a black
  // screen.
  bool dataLayerReady = true;
  try {
    await AlarmDatabase.instance.init();
  } catch (e, s) {
    dataLayerReady = false;
    if (kDebugMode) {
      debugPrint('Data layer failed to initialize: $e\n$s');
    }
  }

  runApp(
    ProviderScope(
      child: AdvancedAlarmApp(dataLayerReady: dataLayerReady),
    ),
  );
}

/// Root widget of the application.
///
/// Hooks up:
///   * Light + dark Material 3 themes (auto-switched by the system).
///   * The [HomeScreen] as the landing surface once the local data
///     layer is ready.
///   * A graceful fallback screen when the data layer failed to
///     initialize, so the app never shows a black screen.
class AdvancedAlarmApp extends StatelessWidget {
  const AdvancedAlarmApp({super.key, this.dataLayerReady = true});

  /// Set to `false` only when [AlarmDatabase.init] threw at startup.
  final bool dataLayerReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Alarm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: dataLayerReady ? const HomeScreen() : const _StorageUnavailableView(),
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
