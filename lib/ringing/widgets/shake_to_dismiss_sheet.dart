import 'package:flutter/material.dart';

/// Bottom sheet that prompts the user to shake the device to dismiss
/// the alarm. Shows live progress against [shakesRequired].
///
/// The sheet itself does **not** subscribe to the accelerometer — that
/// is the [RingingController]'s job. We just visualise the progress
/// reported through [shakeProgress].
class ShakeToDismissSheet extends StatelessWidget {
  const ShakeToDismissSheet({
    super.key,
    required this.shakeProgress,
    required this.shakesRequired,
    required this.onCancel,
  });

  final int shakeProgress;
  final int shakesRequired;
  final VoidCallback onCancel;

  /// Convenience launcher. Returns when the controller leaves the
  /// challenge phase (the caller is responsible for calling
  /// [Navigator.pop] then).
  static Future<void> show(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = shakesRequired == 0
        ? 0.0
        : (shakeProgress / shakesRequired).clamp(0.0, 1.0);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.vibration,
              size: 56,
            ),
            const SizedBox(height: 12),
            const Text(
              'Shake to dismiss',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Shake your phone $shakesRequired times to stop the alarm.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.7,
                    ),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$shakeProgress / $shakesRequired',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onCancel,
              child: const Text('Keep ringing'),
            ),
          ],
        ),
      ),
    );
  }
}
