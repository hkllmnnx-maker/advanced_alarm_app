import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data.dart';

/// Exposes the singleton [AlarmRepository] to the UI tree.
///
/// We use a plain [Provider] (not StateNotifier) because the repository
/// itself is stateless from a Riverpod perspective – it's just a handle
/// to the underlying Hive box. State is observed reactively via
/// [alarmListProvider] below.
///
/// Tests / previews can override this provider with an in-memory or
/// fake implementation:
///
/// ```dart
/// ProviderScope(
///   overrides: <Override>[
///     alarmRepositoryProvider.overrideWithValue(fakeRepo),
///   ],
///   child: MyApp(),
/// )
/// ```
final Provider<AlarmRepository> alarmRepositoryProvider =
    Provider<AlarmRepository>((Ref ref) {
      return AlarmRepository.fromDatabase();
    });

/// Reactive list of all stored alarms, kept in sync with the underlying
/// Hive box. Emits a new value every time an alarm is added, updated,
/// toggled or deleted.
///
/// The repository's [AlarmRepository.watchAll] emits the current snapshot
/// synchronously on subscription, so the first frame already has data
/// (no spinner flash for the common case).
final StreamProvider<List<Alarm>> alarmListProvider =
    StreamProvider<List<Alarm>>((Ref ref) {
      final AlarmRepository repo = ref.watch(alarmRepositoryProvider);
      return repo.watchAll();
    });
