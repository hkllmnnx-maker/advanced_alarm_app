/// A day of the week, aligned with [DateTime.weekday]
/// (Monday = 1 ... Sunday = 7).
///
/// Used to represent a repeating weekly alarm pattern.
enum Weekday {
  monday(1),
  tuesday(2),
  wednesday(3),
  thursday(4),
  friday(5),
  saturday(6),
  sunday(7);

  const Weekday(this.value);

  /// Matches [DateTime.weekday] (1..7).
  final int value;

  /// Safe deserialization. Returns null for unknown values so the caller
  /// can decide how to handle corrupted data instead of throwing.
  static Weekday? fromValue(int? value) {
    switch (value) {
      case 1:
        return Weekday.monday;
      case 2:
        return Weekday.tuesday;
      case 3:
        return Weekday.wednesday;
      case 4:
        return Weekday.thursday;
      case 5:
        return Weekday.friday;
      case 6:
        return Weekday.saturday;
      case 7:
        return Weekday.sunday;
      default:
        return null;
    }
  }
}
