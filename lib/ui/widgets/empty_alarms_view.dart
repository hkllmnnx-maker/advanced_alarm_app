import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Displayed on the home screen when the user has no alarms saved yet.
///
/// We deliberately draw the illustration with a [CustomPainter] instead
/// of bundling a PNG/SVG asset because:
///   * It scales perfectly on every screen / DPR.
///   * Colors adapt automatically to the active [ColorScheme] in both
///     light and dark themes – no need to ship two assets.
///   * Zero binary overhead.
class EmptyAlarmsView extends StatelessWidget {
  const EmptyAlarmsView({super.key, this.onAddPressed});

  /// Optional CTA on the empty-state, in addition to the screen's FAB.
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        // Cap the illustration so it doesn't dominate huge screens.
        final double illustrationSize =
            math.min(220.0, c.maxWidth * 0.6).clamp(140.0, 220.0).toDouble();

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Semantics(
                  label: 'No alarms illustration',
                  image: true,
                  child: SizedBox(
                    width: illustrationSize,
                    height: illustrationSize,
                    child: CustomPaint(
                      painter: _AlarmIllustrationPainter(
                        primary: scheme.primary,
                        primaryContainer: scheme.primaryContainer,
                        onPrimaryContainer: scheme.onPrimaryContainer,
                        surface: scheme.surface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'No alarms yet',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    'Tap the + button to schedule your first alarm. '
                    'You can pick a time, label it, and choose which days '
                    'it should repeat on.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (onAddPressed != null) ...<Widget>[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onAddPressed,
                    icon: const Icon(Icons.add_alarm_rounded),
                    label: const Text('Add your first alarm'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Hand-rolled vector illustration of a sleeping/idle alarm clock.
/// Stays under 100 lines and only uses [Canvas] primitives so it can't
/// drift out of sync with any asset pipeline.
class _AlarmIllustrationPainter extends CustomPainter {
  _AlarmIllustrationPainter({
    required this.primary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.surface,
  });

  final Color primary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2 + h * 0.04);
    final double radius = math.min(w, h) * 0.34;

    // 1. Soft circular background "halo" — gives depth without a shadow.
    canvas.drawCircle(
      Offset(w / 2, h / 2 + h * 0.06),
      radius * 1.55,
      Paint()..color = primaryContainer.withValues(alpha: 0.35),
    );

    // 2. Bells on top of the clock.
    final Paint bellPaint = Paint()..color = primary;
    final double bellRadius = radius * 0.28;
    final Offset leftBell = center.translate(-radius * 0.72, -radius * 0.85);
    final Offset rightBell = center.translate(radius * 0.72, -radius * 0.85);
    canvas.drawCircle(leftBell, bellRadius, bellPaint);
    canvas.drawCircle(rightBell, bellRadius, bellPaint);

    // 3. Two little legs at the bottom.
    final Paint legPaint = Paint()..color = primary;
    final double legW = radius * 0.18;
    final double legH = radius * 0.32;
    final RRect leftLeg = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(-radius * 0.55, radius * 0.95),
        width: legW,
        height: legH,
      ),
      const Radius.circular(6),
    );
    final RRect rightLeg = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(radius * 0.55, radius * 0.95),
        width: legW,
        height: legH,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(leftLeg, legPaint);
    canvas.drawRRect(rightLeg, legPaint);

    // 4. The clock body — primary outer disc with a softer inner face.
    canvas.drawCircle(center, radius, Paint()..color = primary);
    canvas.drawCircle(
      center,
      radius * 0.86,
      Paint()..color = surface,
    );

    // 5. Tick marks at 12 / 3 / 6 / 9.
    final Paint tickPaint = Paint()
      ..color = onPrimaryContainer.withValues(alpha: 0.6)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.06;
    for (int i = 0; i < 4; i++) {
      final double angle = -math.pi / 2 + i * math.pi / 2;
      final Offset outer = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * 0.78);
      final Offset inner = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * 0.66);
      canvas.drawLine(inner, outer, tickPaint);
    }

    // 6. Clock hands — a relaxed "ten past ten" pose.
    final Paint handPaint = Paint()
      ..color = primary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.08;
    // Hour hand pointing roughly to 10.
    final Offset hourEnd = center + const Offset(-0.4, -0.55) * 1;
    canvas.drawLine(
      center,
      Offset(
        center.dx - radius * 0.38,
        center.dy - radius * 0.42,
      ),
      handPaint,
    );
    // Minute hand pointing roughly to 2.
    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * 0.55,
        center.dy - radius * 0.30,
      ),
      handPaint,
    );
    // Suppress unused-variable warning while keeping intent obvious.
    // ignore: unnecessary_statements
    hourEnd;

    // 7. Center pivot.
    canvas.drawCircle(center, radius * 0.07, Paint()..color = primary);

    // 8. Tiny "Zz" floating above the right bell to suggest "no alarms".
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: 'Zz',
        style: TextStyle(
          color: primary,
          fontSize: radius * 0.42,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(rightBell.dx + bellRadius * 0.4,
          rightBell.dy - bellRadius * 1.6),
    );
  }

  @override
  bool shouldRepaint(covariant _AlarmIllustrationPainter old) {
    return old.primary != primary ||
        old.primaryContainer != primaryContainer ||
        old.onPrimaryContainer != onPrimaryContainer ||
        old.surface != surface;
  }
}
