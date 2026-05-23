import 'package:flutter/material.dart';

/// Large, lock-screen-friendly action button used for "Snooze" and
/// "Dismiss" on the ringing screen.
///
/// The button is deliberately oversized (88pt tall) and high-contrast
/// so it remains tappable on a half-awake user holding a phone with
/// dirty fingers.
class BigActionButton extends StatelessWidget {
  const BigActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
    this.foreground = Colors.white,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 88,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(20),
        elevation: 6,
        shadowColor: color.withValues(alpha: 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: foreground, size: 36),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
