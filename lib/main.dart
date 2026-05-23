import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/data.dart';
import 'features/home/home_screen.dart';

/// Entry point of the Advanced Alarm App.
///
/// Bootstraps the Flutter binding and initializes the local data layer
/// (Hive-backed alarm database) before rendering the root [HomeScreen].
/// If the data layer fails to initialize (e.g. corrupted box on disk),
/// the app still launches in a degraded state instead of crashing.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool dataLayerReady = true;
  try {
    await AlarmDatabase.instance.init();
  } catch (e, s) {
    dataLayerReady = false;
    if (kDebugMode) {
      debugPrint('Data layer failed to initialize: $e\n$s');
    }
  }

  runApp(AdvancedAlarmApp(dataLayerReady: dataLayerReady));
}

/// Root [MaterialApp] of the project.
class AdvancedAlarmApp extends StatelessWidget {
  const AdvancedAlarmApp({super.key, this.dataLayerReady = true});

  /// Whether the local persistence layer started up successfully.
  final bool dataLayerReady;

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
