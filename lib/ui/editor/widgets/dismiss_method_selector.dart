import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/dismiss_method.dart';

/// Segmented selector for how the user must dismiss a ringing alarm:
/// simple tap, math puzzle, or shake.
///
/// We don't use Material's [SegmentedButton] directly because we need
/// a richer multi-line label (icon + title + subtitle) and a guaranteed
/// no-overflow layout on narrow screens.
class DismissMethodSelector extends StatelessWidget {
  const DismissMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DismissMethod selected;
  final ValueChanged<DismissMethod> onChanged;

  static const List<_DismissOption> _options = <_DismissOption>[
    _DismissOption(
      method: DismissMethod.tap,
      icon: Icons.touch_app_outlined,
      title: 'Tap',
      subtitle: 'Simple button tap',
    ),
    _DismissOption(
      method: DismissMethod.mathPuzzle,
      icon: Icons.calculate_outlined,
      title: 'Math',
      subtitle: 'Solve a puzzle',
    ),
    _DismissOption(
      method: DismissMethod.shake,
      icon: Icons.vibration,
      title: 'Shake',
      subtitle: 'Shake your phone',
    ),
  ];

  void _select(DismissMethod method) {
    if (method == selected) return;
    HapticFeedback.selectionClick();
    onChanged(method);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Stack vertically on really narrow screens to avoid overflow.
        final bool stacked = constraints.maxWidth < 360;
        if (stacked) {
          return Column(
            children: _options
                .map((_DismissOption o) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _DismissCard(
                        option: o,
                        isSelected: o.method == selected,
                        onTap: () => _select(o.method),
                        cs: cs,
                      ),
                    ))
                .toList(growable: false),
          );
        }
        return Row(
          children: _options
              .map((_DismissOption o) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _DismissCard(
                        option: o,
                        isSelected: o.method == selected,
                        onTap: () => _select(o.method),
                        cs: cs,
                      ),
                    ),
                  ))
              .toList(growable: false),
        );
      },
    );
  }
}

class _DismissOption {
  const _DismissOption({
    required this.method,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final DismissMethod method;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _DismissCard extends StatelessWidget {
  const _DismissCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.cs,
  });

  final _DismissOption option;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? cs.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  option.icon,
                  color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  option.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? cs.onPrimaryContainer
                        : cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? cs.onPrimaryContainer.withValues(alpha: 0.85)
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
