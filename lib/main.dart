import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'features/settings/data/alarms_reset_controller.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsProvider.create();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        // The data layer feature branch will replace this with a Hive-backed
        // implementation. Until then the no-op keeps the destructive action
        // wired and unit-testable.
        Provider<AlarmsResetController>.value(
          value: const NoopAlarmsResetController(),
        ),
      ],
      child: const AdvancedAlarmApp(),
    ),
  );
}

class AdvancedAlarmApp extends StatelessWidget {
  const AdvancedAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch only the slices that the root must rebuild for: theme + locale.
    final themeMode =
        context.select<SettingsProvider, ThemeMode>((p) => p.themeMode);
    final locale = context.select<SettingsProvider, Locale>((p) => p.locale);

    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6750A4),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      ),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _HomeShell(),
    );
  }
}

/// Minimal placeholder home so the settings flow is reachable on its own
/// branch. The `feat/ui-home` branch supplies the real implementation.
class _HomeShell extends StatelessWidget {
  const _HomeShell();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.homeNoSettingsHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
