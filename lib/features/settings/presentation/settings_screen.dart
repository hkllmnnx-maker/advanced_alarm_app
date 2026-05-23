import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../data/alarms_reset_controller.dart';
import '../data/app_settings.dart';
import '../providers/settings_provider.dart';

/// Single-page settings screen.
///
/// All controls are bound to [SettingsProvider] via [context.watch], so a
/// change in any tile rebuilds only what it needs. The whole [MaterialApp]
/// rebuilds for theme/locale through a top-level watcher in `main.dart`.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: ListView(
        children: [
          _SectionHeader(label: l10n.sectionAppearance),
          _ThemeModeTile(current: settings.themeMode),
          const Divider(height: 0),
          _LanguageTile(current: settings.language),

          _SectionHeader(label: l10n.sectionAlarms),
          _TimeFormatTile(use24h: settings.use24hFormat),
          const Divider(height: 0),
          _DefaultSnoozeTile(current: settings.defaultSnoozeMinutes),
          const Divider(height: 0),
          _DefaultRingtoneTile(current: settings.defaultRingtone),

          _SectionHeader(label: l10n.sectionDanger),
          _ResetAlarmsTile(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// =============================================================================
// Section header
// =============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// =============================================================================
// Theme mode
// =============================================================================

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({required this.current});
  final ThemeMode current;

  String _label(AppLocalizations l10n, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return l10n.themeSystem;
      case ThemeMode.light:
        return l10n.themeLight;
      case ThemeMode.dark:
        return l10n.themeDark;
    }
  }

  IconData _icon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(_icon(current)),
      title: Text(l10n.themeMode),
      subtitle: Text(_label(l10n, current)),
      onTap: () async {
        final selected = await showModalBottomSheet<ThemeMode>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ThemeMode.values.map((m) {
                  return _OptionTile<ThemeMode>(
                    value: m,
                    selected: m == current,
                    leading: Icon(_icon(m)),
                    title: _label(l10n, m),
                    onTap: () => Navigator.of(ctx).pop(m),
                  );
                }).toList(),
              ),
            );
          },
        );
        if (selected != null && context.mounted) {
          await context.read<SettingsProvider>().setThemeMode(selected);
        }
      },
    );
  }
}

// =============================================================================
// Language
// =============================================================================

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.current});
  final AppLanguage current;

  String _label(AppLocalizations l10n, AppLanguage lang) {
    switch (lang) {
      case AppLanguage.arabic:
        return l10n.languageArabic;
      case AppLanguage.english:
        return l10n.languageEnglish;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.translate_outlined),
      title: Text(l10n.language),
      subtitle: Text(_label(l10n, current)),
      onTap: () async {
        final selected = await showModalBottomSheet<AppLanguage>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: AppLanguage.values.map((lang) {
                  return _OptionTile<AppLanguage>(
                    value: lang,
                    selected: lang == current,
                    title: _label(l10n, lang),
                    onTap: () => Navigator.of(ctx).pop(lang),
                  );
                }).toList(),
              ),
            );
          },
        );
        if (selected != null && context.mounted) {
          await context.read<SettingsProvider>().setLanguage(selected);
        }
      },
    );
  }
}

// =============================================================================
// Time format
// =============================================================================

class _TimeFormatTile extends StatelessWidget {
  const _TimeFormatTile({required this.use24h});
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SwitchListTile(
      secondary: const Icon(Icons.access_time_outlined),
      title: Text(l10n.timeFormat),
      subtitle: Text(use24h ? l10n.timeFormat24 : l10n.timeFormat12),
      value: use24h,
      onChanged: (v) {
        context.read<SettingsProvider>().setUse24hFormat(v);
      },
    );
  }
}

// =============================================================================
// Default snooze
// =============================================================================

class _DefaultSnoozeTile extends StatelessWidget {
  const _DefaultSnoozeTile({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.snooze_outlined),
      title: Text(l10n.defaultSnooze),
      subtitle: Text(l10n.snoozeMinutes(current)),
      onTap: () async {
        final selected = await showModalBottomSheet<int>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: kAllowedSnoozeMinutes.map((mins) {
                  return _OptionTile<int>(
                    value: mins,
                    selected: mins == current,
                    title: l10n.snoozeMinutes(mins),
                    onTap: () => Navigator.of(ctx).pop(mins),
                  );
                }).toList(),
              ),
            );
          },
        );
        if (selected != null && context.mounted) {
          await context
              .read<SettingsProvider>()
              .setDefaultSnoozeMinutes(selected);
        }
      },
    );
  }
}

// =============================================================================
// Default ringtone
// =============================================================================

class _DefaultRingtoneTile extends StatelessWidget {
  const _DefaultRingtoneTile({required this.current});
  final DefaultRingtone current;

  String _label(AppLocalizations l10n, DefaultRingtone r) {
    switch (r) {
      case DefaultRingtone.classic:
        return l10n.ringtoneClassic;
      case DefaultRingtone.digital:
        return l10n.ringtoneDigital;
      case DefaultRingtone.gentle:
        return l10n.ringtoneGentle;
      case DefaultRingtone.rooster:
        return l10n.ringtoneRooster;
      case DefaultRingtone.ocean:
        return l10n.ringtoneOcean;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.music_note_outlined),
      title: Text(l10n.defaultRingtone),
      subtitle: Text(_label(l10n, current)),
      onTap: () async {
        final selected = await showModalBottomSheet<DefaultRingtone>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: DefaultRingtone.values.map((r) {
                  return _OptionTile<DefaultRingtone>(
                    value: r,
                    selected: r == current,
                    title: _label(l10n, r),
                    onTap: () => Navigator.of(ctx).pop(r),
                  );
                }).toList(),
              ),
            );
          },
        );
        if (selected != null && context.mounted) {
          await context
              .read<SettingsProvider>()
              .setDefaultRingtone(selected);
        }
      },
    );
  }
}

// =============================================================================
// Reset all alarms (destructive)
// =============================================================================

class _ResetAlarmsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;

    return ListTile(
      leading: Icon(Icons.delete_forever_outlined, color: danger),
      title: Text(
        l10n.resetAllAlarms,
        style: TextStyle(color: danger, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(l10n.resetAllAlarmsDescription),
      onTap: () => _confirmAndReset(context),
    );
  }

  Future<void> _confirmAndReset(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.resetConfirmTitle),
          content: Text(l10n.resetConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
                backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final controller = context.read<AlarmsResetController>();
    await controller.resetAllAlarms();

    messenger.showSnackBar(
      SnackBar(content: Text(l10n.alarmsResetSnack)),
    );
  }
}

// =============================================================================
// Shared option tile used by every picker bottom sheet.
// =============================================================================

/// A `ListTile` that emulates the radio-button look without depending on the
/// (currently being reworked) `Radio` / `RadioGroup` API. Keeps the analyzer
/// quiet across Flutter versions while preserving accessibility semantics.
class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.value,
    required this.selected,
    required this.title,
    required this.onTap,
    this.leading,
  });

  final T value;
  final bool selected;
  final String title;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return ListTile(
      leading: leading,
      title: Text(title),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: color,
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}
