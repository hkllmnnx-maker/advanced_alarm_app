import 'package:flutter/material.dart';

import '../../data/models/alarm.dart';
import '../../data/models/weekday.dart';
import '../utils/alarm_formatting.dart';

/// Visually rich card representing a single alarm row on the home screen.
///
/// Layout (kept responsive so it never overflows on small phones):
///
/// ┌────────────────────────────────────────────────────────────┐
/// │  07:30                                              [● ●]  │
/// │  Morning workout                                            │
/// │  [Mon] [Wed] [Fri]                                          │
/// └────────────────────────────────────────────────────────────┘
///
/// All children adapt to [Theme.of] so light/dark mode work for free.
///
/// The card itself is **not** tappable: outer `Dismissible` + `InkWell`
/// concerns belong to the list screen, keeping this widget reusable
/// (e.g. in previews or a future "next alarm" hero on the lock screen).
class AlarmCard extends StatelessWidget {
  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onToggleEnabled,
    this.onTap,
  });

  /// Alarm to render.
  final Alarm alarm;

  /// Called when the user flips the switch. Receives the requested new value.
  final ValueChanged<bool> onToggleEnabled;

  /// Optional: called when the user taps anywhere on the card.
  /// Edit-screen wiring will happen in a later agent, so we leave this
  /// hook in place but unused by default.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;

    // Visually dim the entire card when disabled so the state is obvious.
    final double opacity = alarm.isEnabled ? 1.0 : 0.55;

    final String timeString = AlarmFormatting.formatTime(
      alarm.hour,
      alarm.minute,
    );
    final String repeatSummary =
        AlarmFormatting.repeatSummary(alarm.repeatDays);
    final List<Weekday> orderedDays =
        AlarmFormatting.orderedDays(alarm.repeatDays);

    final String semanticLabel = <String>[
      'Alarm at $timeString',
      if (alarm.label.trim().isNotEmpty) 'labeled "${alarm.label.trim()}"',
      repeatSummary,
      alarm.isEnabled ? 'enabled' : 'disabled',
    ].join(', ');

    return Semantics(
      container: true,
      label: semanticLabel,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: opacity,
        child: Card(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Top row: huge time on the left, switch on the right.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            timeString,
                            // Use displayMedium so it fits even on
                            // very narrow phones, then let FittedBox
                            // scale down if absolutely necessary.
                            style: text.displayMedium?.copyWith(
                              color: scheme.onSurface,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: alarm.isEnabled
                            ? 'Disable alarm'
                            : 'Enable alarm',
                        toggled: alarm.isEnabled,
                        child: Switch.adaptive(
                          value: alarm.isEnabled,
                          onChanged: onToggleEnabled,
                        ),
                      ),
                    ],
                  ),

                  // Label, only rendered when non-empty.
                  if (alarm.label.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      alarm.label.trim(),
                      style: text.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Repeat-days row. Always shown – uses the high-level
                  // "One-time" / "Every day" / "Weekdays" pill when the
                  // pattern matches, otherwise tiny chips per day.
                  _RepeatRow(
                    repeatSummary: repeatSummary,
                    days: orderedDays,
                    isEnabled: alarm.isEnabled,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal widget that picks the right representation for the
/// alarm's repeat pattern:
///   * Nothing checked → single "One-time" pill.
///   * Mon-Fri, weekends or every day → single named pill.
///   * Custom selection → one short chip per day.
class _RepeatRow extends StatelessWidget {
  const _RepeatRow({
    required this.repeatSummary,
    required this.days,
    required this.isEnabled,
  });

  final String repeatSummary;
  final List<Weekday> days;
  final bool isEnabled;

  static const Set<String> _namedPatterns = <String>{
    'One-time',
    'Weekdays',
    'Weekends',
    'Every day',
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // High-level named pattern → single pill.
    if (_namedPatterns.contains(repeatSummary)) {
      return _Pill(
        label: repeatSummary,
        emphasized: isEnabled,
      );
    }

    // Custom subset → small wrap of per-day chips.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final Weekday d in days)
          _DayChip(
            label: AlarmFormatting.shortLabel(d),
            color: scheme.primary,
            onSurface: scheme.onPrimary,
            emphasized: isEnabled,
          ),
      ],
    );
  }
}

/// Single rounded pill ("Weekdays", "One-time", …).
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.emphasized});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color bg = emphasized
        ? scheme.primary.withValues(alpha: 0.15)
        : scheme.surfaceContainerHigh;
    final Color fg = emphasized ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Small per-day chip, e.g. "Mon".
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.color,
    required this.onSurface,
    required this.emphasized,
  });

  final String label;
  final Color color;
  final Color onSurface;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color bg = emphasized
        ? color.withValues(alpha: 0.18)
        : scheme.surfaceContainerHigh;
    final Color fg = emphasized ? color : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}
