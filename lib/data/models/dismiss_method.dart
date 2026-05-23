/// How the user must dismiss a ringing alarm.
///
/// Storing the underlying integer keeps the on-disk representation stable
/// even if we reorder the enum values in the future.
enum DismissMethod {
  /// Simple tap on the dismiss button.
  tap(0),

  /// User must solve a math puzzle to dismiss.
  mathPuzzle(1),

  /// User must shake the phone vigorously to dismiss.
  shake(2);

  const DismissMethod(this.value);

  /// Stable integer value persisted to disk.
  final int value;

  /// Safe deserialization from the persisted integer.
  ///
  /// Falls back to [DismissMethod.tap] if the value is unknown or null
  /// (e.g. data written by a newer app version) so the repository never
  /// crashes on a corrupted record.
  static DismissMethod fromValue(int? value) {
    switch (value) {
      case 1:
        return DismissMethod.mathPuzzle;
      case 2:
        return DismissMethod.shake;
      case 0:
      default:
        return DismissMethod.tap;
    }
  }
}
