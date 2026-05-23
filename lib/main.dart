import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

/// Entry point of the Advanced Alarm App.
///
/// During the bootstrap phase this only ensures the Flutter binding is
/// initialized and renders a placeholder [HomeScreen]. Service initialization
/// (notifications, timezones, Hive, …) will be wired in here in upcoming
/// feature branches.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdvancedAlarmApp());
}

/// Root [MaterialApp] of the project.
class AdvancedAlarmApp extends StatelessWidget {
  const AdvancedAlarmApp({super.key});

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
