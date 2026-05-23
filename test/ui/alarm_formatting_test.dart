// Pure-Dart unit tests for the UI-layer formatting helpers.

import 'package:advanced_alarm_app/data/models/weekday.dart';
import 'package:advanced_alarm_app/ui/utils/alarm_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlarmFormatting.formatTime', () {
    test('zero-pads single-digit hours and minutes', () {
      expect(AlarmFormatting.formatTime(7, 5), '07:05');
    });

    test('renders midnight and just-before-midnight correctly', () {
      expect(AlarmFormatting.formatTime(0, 0), '00:00');
      expect(AlarmFormatting.formatTime(23, 59), '23:59');
    });
  });

  group('AlarmFormatting.repeatSummary', () {
    test('empty set => One-time', () {
      expect(AlarmFormatting.repeatSummary(<Weekday>{}), 'One-time');
    });

    test('all seven days => Every day', () {
      expect(
        AlarmFormatting.repeatSummary(Weekday.values.toSet()),
        'Every day',
      );
    });

    test('Mon–Fri => Weekdays', () {
      expect(
        AlarmFormatting.repeatSummary(<Weekday>{
          Weekday.monday,
          Weekday.tuesday,
          Weekday.wednesday,
          Weekday.thursday,
          Weekday.friday,
        }),
        'Weekdays',
      );
    });

    test('Sat + Sun => Weekends', () {
      expect(
        AlarmFormatting.repeatSummary(<Weekday>{
          Weekday.saturday,
          Weekday.sunday,
        }),
        'Weekends',
      );
    });

    test('custom subset => comma-joined short labels in canonical order', () {
      expect(
        AlarmFormatting.repeatSummary(<Weekday>{
          Weekday.friday,
          Weekday.monday,
          Weekday.wednesday,
        }),
        'Mon, Wed, Fri',
      );
    });
  });

  group('AlarmFormatting.orderedDays', () {
    test('returns days in Monday → Sunday order regardless of input order', () {
      final List<Weekday> ordered = AlarmFormatting.orderedDays(
        <Weekday>{Weekday.sunday, Weekday.tuesday, Weekday.friday},
      );
      expect(ordered, <Weekday>[Weekday.tuesday, Weekday.friday, Weekday.sunday]);
    });
  });

  group('AlarmFormatting.shortLabel', () {
    test('returns three-letter English label for each weekday', () {
      expect(AlarmFormatting.shortLabel(Weekday.monday), 'Mon');
      expect(AlarmFormatting.shortLabel(Weekday.tuesday), 'Tue');
      expect(AlarmFormatting.shortLabel(Weekday.wednesday), 'Wed');
      expect(AlarmFormatting.shortLabel(Weekday.thursday), 'Thu');
      expect(AlarmFormatting.shortLabel(Weekday.friday), 'Fri');
      expect(AlarmFormatting.shortLabel(Weekday.saturday), 'Sat');
      expect(AlarmFormatting.shortLabel(Weekday.sunday), 'Sun');
    });
  });
}
