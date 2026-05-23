/// Public barrel for the data layer.
///
/// Anything the rest of the app (or tests) needs from `lib/data/` should
/// be re-exported from here so callers only have to write:
///
/// ```dart
/// import 'package:advanced_alarm_app/data/data.dart';
/// ```
library;

export 'database/alarm_database.dart';
export 'models/alarm.dart';
export 'models/dismiss_method.dart';
export 'models/weekday.dart';
export 'repositories/alarm_repository.dart';
