import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Listens to the device accelerometer and counts vigorous shakes.
///
/// A shake is registered whenever the acceleration magnitude (with
/// gravity removed) exceeds [shakeThresholdGForce] and the previous
/// shake was registered at least [_minTimeBetweenShakes] ago. After
/// [shakesRequired] qualifying shakes the [_onShakesComplete] callback
/// is invoked and the detector auto-stops.
///
/// Implementation notes:
///  * Uses the *unfiltered* accelerometer (`accelerometerEventStream`).
///    The sensor already includes gravity, so we subtract `9.81` (~1g)
///    from the magnitude before comparing to the threshold. This works
///    consistently in any device orientation.
///  * Defensive against the sensor stream firing very rapidly: the
///    [_minTimeBetweenShakes] debounce avoids counting a single
///    vigorous swing as 5 separate shakes.
class ShakeDetector {
  ShakeDetector({this.shakeThresholdGForce = 2.7, this.shakesRequired = 5});

  /// Acceleration in g-force (above gravity) required to register a
  /// shake. 2.7 g is a good default: gentle wrist motion is ~1.5 g,
  /// deliberate vigorous shakes easily exceed 3 g.
  final double shakeThresholdGForce;

  /// How many qualifying shakes must be detected before the user is
  /// considered to have completed the gesture.
  final int shakesRequired;

  static const Duration _minTimeBetweenShakes = Duration(milliseconds: 220);

  StreamSubscription<AccelerometerEvent>? _sub;
  VoidCallback? _onShakesComplete;
  ValueChanged<int>? _onProgress;

  int _count = 0;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  bool _started = false;
  bool _stopped = false;

  /// Number of qualifying shakes detected in the current run.
  int get shakeCount => _count;

  /// Whether the detector is currently listening.
  bool get isListening => _started && !_stopped;

  /// Starts listening to the accelerometer.
  ///
  /// * [onShakesComplete] — called exactly once, when the user has
  ///   produced [shakesRequired] shakes. The detector auto-stops right
  ///   after invoking the callback so it cannot fire twice.
  /// * [onProgress] — optional progress callback invoked with the
  ///   updated [shakeCount] after every qualifying shake. Useful to
  ///   drive a progress bar in the UI.
  void start({
    required VoidCallback onShakesComplete,
    ValueChanged<int>? onProgress,
  }) {
    if (_started) return;
    _started = true;
    _stopped = false;
    _count = 0;
    _onShakesComplete = onShakesComplete;
    _onProgress = onProgress;

    try {
      _sub =
          accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 20),
          ).listen(
            _onEvent,
            onError: (Object e, StackTrace st) {
              if (kDebugMode) {
                debugPrint('ShakeDetector stream error: $e\n$st');
              }
            },
            cancelOnError: false,
          );
    } catch (e) {
      // Sensor might be unavailable (emulator without sensors). The
      // ringing controller falls back to the Snooze button so the
      // alarm is still dismissible — log and move on.
      if (kDebugMode) {
        debugPrint('ShakeDetector failed to subscribe: $e');
      }
    }
  }

  /// Stops listening and releases the accelerometer subscription.
  /// Idempotent.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    final StreamSubscription<AccelerometerEvent>? sub = _sub;
    _sub = null;
    await sub?.cancel();
  }

  Future<void> dispose() => stop();

  void _onEvent(AccelerometerEvent event) {
    if (_stopped) return;
    final double gForce = _gForce(event.x, event.y, event.z);
    if (gForce < shakeThresholdGForce) return;

    final DateTime now = DateTime.now();
    if (now.difference(_lastShake) < _minTimeBetweenShakes) return;
    _lastShake = now;

    _count++;
    _onProgress?.call(_count);
    if (_count >= shakesRequired) {
      final VoidCallback? cb = _onShakesComplete;
      // Disarm before calling the callback so a synchronous re-entry
      // can never trigger a second completion.
      _onShakesComplete = null;
      stop();
      cb?.call();
    }
  }

  /// Returns the linear acceleration magnitude (with gravity removed)
  /// in units of g (9.81 m/s²).
  static double _gForce(double x, double y, double z) {
    final double magnitude = math.sqrt(x * x + y * y + z * z);
    // Subtract gravity (~9.81 m/s²) to get the dynamic component, then
    // convert m/s² → g. Clamp to >= 0 because rapid free-fall would
    // otherwise produce a negative value.
    final double dynamic = (magnitude - 9.81).abs();
    return dynamic / 9.81;
  }
}
