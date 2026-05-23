import '../../data/models/weekday.dart';

/// Pure (no Flutter imports) helpers used by the UI to display
/// human-friendly representations of an [Alarm].
///
/// Kept in `lib/ui/utils/` rather than the data layer because these
/// formats are presentation concerns – the data layer must stay
/// framework-agnostic.
class AlarmFormatting {
  AlarmFormatting._();

  /// Formats a `(hour, minute)` pair as `HH:mm` (24h, zero-padded).
  ///
  /// Example: `(7, 5) → "07:05"`.
  static String formatTime(int hour, int minute) {
    final String hh = hour.toString().padLeft(2, '0');
    final String mm = minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Short two-letter label for a weekday, suitable for chip badges.
  static String shortLabel(Weekday day) {
    switch (day) {
      case Weekday.monday:
        return 'Mon';
      case Weekday.tuesday:
        return 'Tue';
      case Weekday.wednesday:
        return 'Wed';
      case Weekday.thursday:
        return 'Thu';
      case Weekday.friday:
        return 'Fri';
      case Weekday.saturday:
        return 'Sat';
      case Weekday.sunday:
        return 'Sun';
    }
  }

  /// Returns the canonical [Weekday] order (Mon → Sun) so chips are
  /// displayed consistently regardless of how the [Set] was built.
  static List<Weekday> orderedDays(Set<Weekday> days) {
    const List<Weekday> order = <Weekday>[
      Weekday.monday,
      Weekday.tuesday,
      Weekday.wednesday,
      Weekday.thursday,
      Weekday.friday,
      Weekday.saturday,
      Weekday.sunday,
    ];
    return order.where(days.contains).toList(growable: false);
  }

  /// A high-level description of the repeat pattern, used as a subtitle
  /// and in semantic labels for screen readers.
  ///
  ///   * `{}`              → "One-time"
  ///   * Mon-Fri set       → "Weekdays"
  ///   * Sat + Sun         → "Weekends"
  ///   * All 7 days        → "Every day"
  ///   * Anything else     → comma-joined short labels (e.g. "Mon, Wed, Fri")
  static String repeatSummary(Set<Weekday> days) {
    if (days.isEmpty) return 'One-time';
    const Set<Weekday> weekdays = <Weekday>{
      Weekday.monday,
      Weekday.tuesday,
      Weekday.wednesday,
      Weekday.thursday,
      Weekday.friday,
    };
    const Set<Weekday> weekends = <Weekday>{Weekday.saturday, Weekday.sunday};
    if (days.length == 7) return 'Every day';
    if (days.length == weekdays.length &&
        days.containsAll(weekdays) &&
        weekdays.containsAll(days)) {
      return 'Weekdays';
    }
    if (days.length == weekends.length &&
        days.containsAll(weekends) &&
        weekends.containsAll(days)) {
      return 'Weekends';
    }
    return orderedDays(days).map(shortLabel).join(', ');
  }
}
