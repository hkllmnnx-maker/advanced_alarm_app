import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Tiny wrapper around `wakelock_plus` that:
///  * tracks whether we currently own the wakelock,
///  * makes [release] safe to call multiple times,
///  * never throws — failures are logged in debug builds only.
///
/// We intentionally always *release* in `dispose()`, never just trust
/// the OS to do it for us, so an exception in the ringing flow can never
/// leak a permanent "screen always on" state onto the user's device.
class WakelockGuard {
  WakelockGuard();

  bool _enabled = false;

  bool get isHeld => _enabled;

  Future<void> acquire() async {
    if (_enabled) return;
    try {
      await WakelockPlus.enable();
      _enabled = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WakelockGuard.acquire failed: $e');
      }
    }
  }

  Future<void> release() async {
    if (!_enabled) return;
    try {
      await WakelockPlus.disable();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WakelockGuard.release failed: $e');
      }
    } finally {
      // Always flip the flag, even on failure, so a second call doesn't
      // attempt the same disable again and we don't pretend to "still
      // hold" something we don't.
      _enabled = false;
    }
  }

  Future<void> dispose() => release();
}
