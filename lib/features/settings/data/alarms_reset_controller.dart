import 'package:flutter/foundation.dart';

/// Contract for the destructive "delete every alarm" action invoked from
/// the Settings screen.
///
/// This file deliberately stays free of any storage / Hive dependency so the
/// settings feature compiles in isolation and can be merged into the main
/// branch ahead of the data layer. The data layer feature branch is expected
/// to provide a concrete implementation backed by Hive.
abstract class AlarmsResetController {
  /// Permanently delete every alarm. Returns the number of alarms removed
  /// so the UI can show meaningful feedback.
  Future<int> resetAllAlarms();
}

/// No-op implementation used until the data layer is merged. Reports zero
/// removals but otherwise behaves correctly, so the UI flow can be exercised
/// end-to-end and tested today.
class NoopAlarmsResetController implements AlarmsResetController {
  const NoopAlarmsResetController();

  @override
  Future<int> resetAllAlarms() async {
    if (kDebugMode) {
      debugPrint(
        'NoopAlarmsResetController: resetAllAlarms() called — '
        'no data layer wired yet.',
      );
    }
    return 0;
  }
}
