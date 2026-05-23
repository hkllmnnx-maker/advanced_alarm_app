/// Barrel file for core services.
///
/// Re-exports the public surface of every core service so consumers can
/// import them via a single, stable path:
///
/// ```dart
/// import 'package:advanced_alarm_app/core/services/services.dart';
/// ```
library;

export 'alarm_service.dart';
export 'notification_service.dart';
export 'permission_service.dart';
