import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// Drives the haptic feedback that accompanies a ringing alarm.
///
/// Uses an explicit [Timer.periodic] loop instead of the plugin's
/// built-in repeat parameter so we can:
///
///  * cancel mid-pattern without waiting for the current cycle to end;
///  * survive plugins that do not honour the `repeat:-1` semantics on
///    every Android OEM (we have seen this fail silently on a few
///    devices);
///  * keep a single source of truth for "is the device currently
///    vibrating for this alarm" via [isVibrating].
class AlarmVibrator {
  AlarmVibrator();

  /// Long-short-long-short pattern — recognisable as an alarm without
  /// being painful. Lengths are in milliseconds, alternating
  /// wait/vibrate starting with `wait`.
  static const List<int> _pattern = <int>[
    0, // initial wait
    600, // vibrate
    400, // wait
    600, // vibrate
    400, // wait
    1200, // vibrate
    1200, // wait
  ];

  /// Period of a single pattern cycle, used to schedule the repeater.
  static Duration get _cycleDuration {
    int total = 0;
    for (final int v in _pattern) {
      total += v;
    }
    return Duration(milliseconds: total);
  }

  Timer? _repeater;
  bool _started = false;
  bool _stopped = false;
  bool _hasVibrator = false;

  /// Whether the vibrator is currently active.
  bool get isVibrating => _started && !_stopped;

  /// Starts the repeating vibration pattern.
  ///
  /// Silently no-ops if the device has no vibrator (e.g. tablets), so
  /// callers can always call it unconditionally.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _stopped = false;

    try {
      _hasVibrator = (await Vibration.hasVibrator()) == true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmVibrator.hasVibrator failed: $e');
      }
      _hasVibrator = false;
    }
    if (!_hasVibrator) return;

    await _fireOnce();

    _repeater = Timer.periodic(_cycleDuration, (Timer t) async {
      if (_stopped) {
        t.cancel();
        return;
      }
      await _fireOnce();
    });
  }

  /// Stops vibration and cancels the repeater. Idempotent.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _repeater?.cancel();
    _repeater = null;
    if (!_hasVibrator) return;
    try {
      await Vibration.cancel();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmVibrator.cancel failed: $e');
      }
    }
  }

  Future<void> dispose() => stop();

  Future<void> _fireOnce() async {
    if (_stopped || !_hasVibrator) return;
    try {
      await Vibration.vibrate(pattern: _pattern);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmVibrator.vibrate failed: $e');
      }
    }
  }
}
