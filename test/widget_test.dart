import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:advanced_alarm_app/features/settings/data/alarms_reset_controller.dart';
import 'package:advanced_alarm_app/features/settings/data/app_settings.dart';
import 'package:advanced_alarm_app/features/settings/presentation/settings_screen.dart';
import 'package:advanced_alarm_app/features/settings/providers/settings_provider.dart';
import 'package:advanced_alarm_app/l10n/app_localizations.dart';

Future<Widget> _buildHarness({Locale locale = const Locale('en')}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = await SettingsProvider.create();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      Provider<AlarmsResetController>.value(
        value: const NoopAlarmsResetController(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('Settings screen renders English strings', (tester) async {
    final harness = await _buildHarness();
    await tester.pumpWidget(harness);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Time format'), findsOneWidget);
    expect(find.text('Default snooze duration'), findsOneWidget);
    expect(find.text('Default ringtone'), findsOneWidget);
    expect(find.text('Reset all alarms'), findsOneWidget);
  });

  testWidgets('Settings screen renders Arabic strings + RTL direction',
      (tester) async {
    final harness = await _buildHarness(locale: const Locale('ar'));
    await tester.pumpWidget(harness);
    await tester.pumpAndSettle();

    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('السمة'), findsOneWidget);
    expect(find.text('اللغة'), findsOneWidget);
    expect(find.text('حذف جميع المنبهات'), findsOneWidget);

    final directionality =
        tester.widget<Directionality>(find.byType(Directionality).first);
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('Toggling 24h switch updates the provider instantly',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsProvider.create();
    expect(settings.use24hFormat, isTrue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<AlarmsResetController>.value(
            value: const NoopAlarmsResetController(),
          ),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(settings.use24hFormat, isFalse);
  });

  test('SettingsProvider persists changes through SharedPreferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final provider = await SettingsProvider.create();

    await provider.setLanguage(AppLanguage.arabic);
    await provider.setThemeMode(ThemeMode.dark);
    await provider.setDefaultSnoozeMinutes(15);
    await provider.setDefaultRingtone(DefaultRingtone.ocean);
    await provider.setUse24hFormat(false);

    // Re-create from the same backing store to confirm persistence.
    final reloaded = await SettingsProvider.create();
    expect(reloaded.language, AppLanguage.arabic);
    expect(reloaded.themeMode, ThemeMode.dark);
    expect(reloaded.defaultSnoozeMinutes, 15);
    expect(reloaded.defaultRingtone, DefaultRingtone.ocean);
    expect(reloaded.use24hFormat, isFalse);
  });

  test('resetToDefaults restores AppSettings.defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final provider = await SettingsProvider.create();
    await provider.setThemeMode(ThemeMode.dark);
    await provider.setLanguage(AppLanguage.arabic);

    await provider.resetToDefaults();
    expect(provider.settings, AppSettings.defaults);
  });
}
