import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/weekday.dart';

/// Sunday-first chip row used to pick which weekdays an alarm repeats on.
///
/// Tapping a chip toggles it. Long-pressing a chip is reserved for future
/// "shortcut" actions (e.g. "weekdays only") and currently no-ops safely.
///
/// Emits the full updated set through [onChanged] every change, so the
/// parent state holder remains the source of truth.
class WeekdaySelector extends StatelessWidget {
  const WeekdaySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<Weekday> selected;
  final ValueChanged<Set<Weekday>> onChanged;

  /// Sun, Mon, Tue, Wed, Thu, Fri, Sat – English short labels.
  /// Using a stable list keeps tests deterministic across locales.
  static const List<_WeekdayLabel> _labels = <_WeekdayLabel>[
    _WeekdayLabel(Weekday.sunday, 'Sun'),
    _WeekdayLabel(Weekday.monday, 'Mon'),
    _WeekdayLabel(Weekday.tuesday, 'Tue'),
    _WeekdayLabel(Weekday.wednesday, 'Wed'),
    _WeekdayLabel(Weekday.thursday, 'Thu'),
    _WeekdayLabel(Weekday.friday, 'Fri'),
    _WeekdayLabel(Weekday.saturday, 'Sat'),
  ];

  void _toggle(Weekday day) {
    final Set<Weekday> next = <Weekday>{...selected};
    if (!next.add(day)) next.remove(day);
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _labels.map((_WeekdayLabel item) {
        final bool isSelected = selected.contains(item.day);
        return _DayChip(
          label: item.shortLabel,
          isSelected: isSelected,
          onTap: () => _toggle(item.day),
          activeColor: cs.primary,
          activeForeground: cs.onPrimary,
          inactiveColor: cs.surfaceContainerHighest,
          inactiveForeground: cs.onSurfaceVariant,
        );
      }).toList(growable: false),
    );
  }
}

class _WeekdayLabel {
  const _WeekdayLabel(this.day, this.shortLabel);

  final Weekday day;
  final String shortLabel;
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.activeForeground,
    required this.inactiveColor,
    required this.inactiveForeground,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color activeForeground;
  final Color inactiveColor;
  final Color inactiveForeground;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: isSelected ? activeForeground : inactiveForeground,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
