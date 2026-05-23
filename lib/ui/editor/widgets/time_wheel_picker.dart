import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Elegant wheel-style time picker for the alarm editor.
///
/// Two infinite-scrolling wheels (hours 0..23, minutes 0..59) inspired
/// by the iOS picker, but themed to match Material 3.
///
/// Features:
///  * Emits [onChanged] every time either wheel settles on a new value.
///  * Provides a subtle haptic "tick" while spinning – matching native
///    feel – without spamming the system buzzer.
///  * Fully clamped: any out-of-range initial value is silently
///    coerced into the legal 0..23 / 0..59 range.
///  * Bounded height so it never causes parent overflow.
class TimeWheelPicker extends StatefulWidget {
  const TimeWheelPicker({
    super.key,
    required this.initialHour,
    required this.initialMinute,
    required this.onChanged,
    this.itemExtent = 44,
    this.visibleItemCount = 5,
  })  : assert(itemExtent > 0, 'itemExtent must be > 0'),
        assert(visibleItemCount > 0, 'visibleItemCount must be > 0');

  final int initialHour;
  final int initialMinute;
  final ValueChanged<TimeOfDay> onChanged;
  final double itemExtent;
  final int visibleItemCount;

  @override
  State<TimeWheelPicker> createState() => _TimeWheelPickerState();
}

class _TimeWheelPickerState extends State<TimeWheelPicker> {
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialHour.clamp(0, 23);
    _minute = widget.initialMinute.clamp(0, 59);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void didUpdateWidget(covariant TimeWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent forces a new initial value (e.g. picking "now"),
    // jump the wheels there without notifying back – we don't want to
    // bounce a redundant onChanged.
    final int newHour = widget.initialHour.clamp(0, 23);
    final int newMinute = widget.initialMinute.clamp(0, 59);
    if (newHour != _hour) {
      _hour = newHour;
      _hourCtrl.jumpToItem(newHour);
    }
    if (newMinute != _minute) {
      _minute = newMinute;
      _minuteCtrl.jumpToItem(newMinute);
    }
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));
  }

  void _onHourChanged(int value) {
    if (value == _hour) return;
    _hour = value;
    HapticFeedback.selectionClick();
    _emit();
  }

  void _onMinuteChanged(int value) {
    if (value == _minute) return;
    _minute = value;
    HapticFeedback.selectionClick();
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final double height = widget.itemExtent * widget.visibleItemCount;

    return SizedBox(
      height: height,
      child: Stack(
        children: <Widget>[
          // Selection highlight bar in the center.
          Center(
            child: Container(
              height: widget.itemExtent,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: _Wheel(
                  controller: _hourCtrl,
                  itemCount: 24,
                  itemExtent: widget.itemExtent,
                  onChanged: _onHourChanged,
                  labelBuilder: (int i) => i.toString().padLeft(2, '0'),
                  semanticsLabel: 'Hours',
                ),
              ),
              SizedBox(
                width: 16,
                child: Center(
                  child: Text(
                    ':',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _Wheel(
                  controller: _minuteCtrl,
                  itemCount: 60,
                  itemExtent: widget.itemExtent,
                  onChanged: _onMinuteChanged,
                  labelBuilder: (int i) => i.toString().padLeft(2, '0'),
                  semanticsLabel: 'Minutes',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.itemCount,
    required this.itemExtent,
    required this.onChanged,
    required this.labelBuilder,
    required this.semanticsLabel,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final double itemExtent;
  final ValueChanged<int> onChanged;
  final String Function(int index) labelBuilder;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: itemExtent,
        useMagnifier: true,
        magnification: 1.15,
        squeeze: 1.1,
        selectionOverlay: const SizedBox.shrink(),
        diameterRatio: 1.4,
        onSelectedItemChanged: onChanged,
        children: List<Widget>.generate(itemCount, (int i) {
          return Center(
            child: Text(
              labelBuilder(i),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
