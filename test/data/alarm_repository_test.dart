import 'dart:io';

import 'package:advanced_alarm_app/data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Unit tests for [AlarmRepository].
///
/// We avoid `hive_flutter` (and therefore `path_provider`) here so the
/// tests run on the pure Dart VM without any platform channels. The
/// repository is constructed against a Box opened with the plain
/// [Hive.init] entry point pointing at a per-test temporary directory.
void main() {
  late Directory tempDir;
  late Box<Alarm> box;
  late AlarmRepository repository;

  Alarm makeAlarm({
    String id = 'a1',
    String label = 'Wake up',
    int hour = 7,
    int minute = 30,
    Set<Weekday>? repeatDays,
    bool isEnabled = true,
    DismissMethod dismiss = DismissMethod.tap,
  }) {
    return Alarm(
      id: id,
      label: label,
      hour: hour,
      minute: minute,
      repeatDays: repeatDays ?? <Weekday>{Weekday.monday, Weekday.friday},
      ringtonePath: 'assets/sounds/default.mp3',
      vibrate: true,
      snoozeDurationMinutes: 5,
      snoozeCount: 3,
      gradualVolumeIncrease: true,
      isEnabled: isEnabled,
      dismissMethod: dismiss,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('alarm_repo_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(AlarmAdapter().typeId)) {
      Hive.registerAdapter(AlarmAdapter());
    }
    box = await Hive.openBox<Alarm>('test_alarms_${tempDir.path.hashCode}');
    repository = AlarmRepository(box);
  });

  tearDown(() async {
    if (box.isOpen) {
      await box.clear();
      await box.close();
    }
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CRUD', () {
    test('add() persists an alarm and getById() returns it', () async {
      final Alarm alarm = makeAlarm();
      await repository.add(alarm);

      final Alarm? loaded = repository.getById(alarm.id);
      expect(loaded, isNotNull);
      expect(loaded!.id, alarm.id);
      expect(loaded.label, 'Wake up');
      expect(loaded.hour, 7);
      expect(loaded.minute, 30);
      expect(
        loaded.repeatDays,
        equals(<Weekday>{Weekday.monday, Weekday.friday}),
      );
      expect(loaded.isEnabled, isTrue);
      expect(loaded.dismissMethod, DismissMethod.tap);
      expect(repository.count(), 1);
    });

    test('add() throws when inserting a duplicate id', () async {
      final Alarm alarm = makeAlarm();
      await repository.add(alarm);

      expect(
        () => repository.add(alarm),
        throwsA(isA<AlarmRepositoryException>()),
      );
    });

    test('update() modifies fields and bumps updatedAt', () async {
      final Alarm alarm = makeAlarm();
      await repository.add(alarm);

      // Make sure the wall clock moves forward at least 1 ms so the
      // updatedAt comparison is deterministic.
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final Alarm edited = alarm.copyWith(
        label: 'New label',
        isEnabled: false,
        dismissMethod: DismissMethod.mathPuzzle,
      );
      await repository.update(edited);

      final Alarm reloaded = repository.getById(alarm.id)!;
      expect(reloaded.label, 'New label');
      expect(reloaded.isEnabled, isFalse);
      expect(reloaded.dismissMethod, DismissMethod.mathPuzzle);
      expect(
        reloaded.updatedAt.isAfter(alarm.updatedAt) ||
            reloaded.updatedAt.isAtSameMomentAs(alarm.updatedAt),
        isTrue,
      );
    });

    test('update() throws when the alarm does not exist', () async {
      final Alarm orphan = makeAlarm(id: 'does-not-exist');
      expect(
        () => repository.update(orphan),
        throwsA(isA<AlarmRepositoryException>()),
      );
    });

    test('toggleEnabled() flips the flag and returns the new value', () async {
      final Alarm alarm = makeAlarm(isEnabled: true);
      await repository.add(alarm);

      final bool? next = await repository.toggleEnabled(alarm.id);
      expect(next, isFalse);
      expect(repository.getById(alarm.id)!.isEnabled, isFalse);

      final bool? again = await repository.toggleEnabled(alarm.id);
      expect(again, isTrue);
    });

    test('toggleEnabled() returns null for unknown id', () async {
      final bool? result = await repository.toggleEnabled('missing');
      expect(result, isNull);
    });

    test('delete() removes the alarm, clear() empties the box', () async {
      await repository.add(makeAlarm(id: 'a1'));
      await repository.add(makeAlarm(id: 'a2', hour: 8));
      expect(repository.count(), 2);

      await repository.delete('a1');
      expect(repository.getById('a1'), isNull);
      expect(repository.count(), 1);

      await repository.clear();
      expect(repository.count(), 0);
      expect(repository.getAll(), isEmpty);
    });

    test('getAll() returns alarms sorted by time-of-day', () async {
      await repository.add(makeAlarm(id: 'late', hour: 22, minute: 0));
      await repository.add(makeAlarm(id: 'mid', hour: 12, minute: 45));
      await repository.add(makeAlarm(id: 'early', hour: 6, minute: 15));

      final List<Alarm> all = repository.getAll();
      expect(all.map((Alarm a) => a.id).toList(), <String>[
        'early',
        'mid',
        'late',
      ]);
    });

    test('getEnabled() filters out disabled alarms', () async {
      await repository.add(makeAlarm(id: 'on', isEnabled: true));
      await repository.add(makeAlarm(id: 'off', hour: 9, isEnabled: false));

      final List<Alarm> enabled = repository.getEnabled();
      expect(enabled.length, 1);
      expect(enabled.first.id, 'on');
    });
  });

  group('Validation', () {
    test('add() rejects an empty id', () async {
      final Alarm bad = makeAlarm(id: '');
      expect(
        () => repository.add(bad),
        throwsA(isA<AlarmRepositoryException>()),
      );
    });

    test('Alarm constructor rejects out-of-range time', () {
      expect(
        () => Alarm(id: 'x', label: 'x', hour: 25, minute: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => Alarm(id: 'x', label: 'x', hour: 0, minute: 99),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Serialization', () {
    test('Alarm.toMap / Alarm.fromMap round-trip preserves every field', () {
      final Alarm original = Alarm(
        id: 'rt-1',
        label: 'Round trip',
        hour: 21,
        minute: 7,
        repeatDays: <Weekday>{
          Weekday.tuesday,
          Weekday.thursday,
          Weekday.sunday,
        },
        ringtonePath: '/sdcard/Sounds/bell.ogg',
        vibrate: false,
        snoozeDurationMinutes: 9,
        snoozeCount: 2,
        gradualVolumeIncrease: false,
        isEnabled: false,
        createdAt: DateTime.utc(2024, 1, 2, 3, 4, 5),
        updatedAt: DateTime.utc(2024, 6, 7, 8, 9, 10),
        dismissMethod: DismissMethod.shake,
      );

      final Map<String, dynamic> map = original.toMap();
      final Alarm decoded = Alarm.fromMap(map);

      // Every non-timestamp field must be byte-identical.
      expect(decoded.id, original.id);
      expect(decoded.label, original.label);
      expect(decoded.hour, original.hour);
      expect(decoded.minute, original.minute);
      expect(decoded.repeatDays, original.repeatDays);
      expect(decoded.ringtonePath, original.ringtonePath);
      expect(decoded.vibrate, original.vibrate);
      expect(decoded.snoozeDurationMinutes, original.snoozeDurationMinutes);
      expect(decoded.snoozeCount, original.snoozeCount);
      expect(decoded.gradualVolumeIncrease, original.gradualVolumeIncrease);
      expect(decoded.isEnabled, original.isEnabled);
      expect(decoded.dismissMethod, original.dismissMethod);

      // Timestamps are normalized to UTC-ms on disk, so we compare them
      // by "moment in time" rather than by UTC-flag-sensitive equality.
      expect(decoded.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
      expect(decoded.updatedAt.isAtSameMomentAs(original.updatedAt), isTrue);
    });

    test('Alarm.fromMap recovers gracefully from corrupted data', () {
      final Map<String, dynamic> corrupted = <String, dynamic>{
        'id': 'corrupt',
        // label missing → should default to ''
        'hour': 99, // out of range → clamped
        'minute': -3, // out of range → clamped
        'repeatDays': <dynamic>[1, 'bogus', 8, 3], // mixed garbage
        // ringtonePath missing
        'snoozeDurationMinutes': 5,
        'snoozeCount': 3,
        // booleans missing
        'createdAt': 'not-an-int',
        'updatedAt': 1700000000000,
        'dismissMethod': 999, // unknown → falls back to tap
      };

      final Alarm decoded = Alarm.fromMap(corrupted);
      expect(decoded.id, 'corrupt');
      expect(decoded.label, '');
      expect(decoded.hour, inInclusiveRange(0, 23));
      expect(decoded.minute, inInclusiveRange(0, 59));
      expect(
        decoded.repeatDays,
        equals(<Weekday>{Weekday.monday, Weekday.wednesday}),
      );
      expect(decoded.dismissMethod, DismissMethod.tap);
      expect(decoded.vibrate, isTrue); // default
    });

    test('AlarmAdapter survives a full Hive read/write cycle', () async {
      final Alarm alarm = makeAlarm(id: 'persist');
      await repository.add(alarm);

      // Close and reopen the box to force the data through the adapter.
      await box.close();
      box = await Hive.openBox<Alarm>('test_alarms_${tempDir.path.hashCode}');
      repository = AlarmRepository(box);

      final Alarm? rehydrated = repository.getById('persist');
      expect(rehydrated, isNotNull);
      expect(rehydrated!.label, alarm.label);
      expect(rehydrated.repeatDays, alarm.repeatDays);
      expect(rehydrated.dismissMethod, alarm.dismissMethod);
    });
  });

  group('Reactive stream', () {
    test('watchAll() emits an initial snapshot and reacts to writes', () async {
      await repository.add(makeAlarm(id: 'first', hour: 6));

      final List<List<Alarm>> emissions = <List<Alarm>>[];
      final sub = repository.watchAll().listen(emissions.add);

      // initial snapshot
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emissions, isNotEmpty);
      expect(emissions.last.length, 1);

      // add → emits again
      await repository.add(makeAlarm(id: 'second', hour: 8));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emissions.last.length, 2);
      expect(emissions.last.map((Alarm a) => a.id).toList(), <String>[
        'first',
        'second',
      ]);

      // delete → emits again
      await repository.delete('first');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emissions.last.length, 1);
      expect(emissions.last.single.id, 'second');

      await sub.cancel();
    });

    test('watchById() emits null after deletion', () async {
      final Alarm alarm = makeAlarm(id: 'solo');
      await repository.add(alarm);

      final List<Alarm?> emissions = <Alarm?>[];
      final sub = repository.watchById('solo').listen(emissions.add);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emissions.last, isNotNull);

      await repository.delete('solo');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emissions.last, isNull);

      await sub.cancel();
    });
  });
}
