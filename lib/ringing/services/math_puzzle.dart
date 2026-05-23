import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A single arithmetic puzzle the user must solve to dismiss the alarm.
@immutable
class MathPuzzle {
  const MathPuzzle({
    required this.left,
    required this.right,
    required this.op,
    required this.answer,
  });

  final int left;
  final int right;
  final MathOp op;
  final int answer;

  /// Pretty-printable form, e.g. `"23 × 7 = ?"`.
  String get question => '$left ${op.symbol} $right';

  /// Returns true when [input] matches the expected [answer]. Whitespace
  /// is trimmed and a sign-only `-` is treated as no input (returns
  /// false) instead of throwing.
  bool isCorrect(String input) {
    final String s = input.trim();
    if (s.isEmpty || s == '-' || s == '+') return false;
    final int? parsed = int.tryParse(s);
    if (parsed == null) return false;
    return parsed == answer;
  }
}

/// Arithmetic operator supported by the puzzle generator.
enum MathOp {
  add('+'),
  subtract('−'),
  multiply('×');

  const MathOp(this.symbol);
  final String symbol;
}

/// Difficulty knob for [MathPuzzleGenerator].
enum MathPuzzleDifficulty {
  /// Single-digit additions / subtractions. Solvable in ~5 seconds even
  /// half-asleep — useful for testing the *flow* without making the
  /// user angry at us.
  easy,

  /// Two-digit additions / subtractions and small multiplications.
  /// Default level.
  medium,

  /// Two-digit multiplications. Genuinely wakes you up.
  hard,
}

/// Generates [MathPuzzle] instances of varying difficulty.
///
/// A custom [math.Random] can be injected for reproducible tests; in
/// production we use a fresh seedless [math.Random] per generator.
class MathPuzzleGenerator {
  MathPuzzleGenerator({math.Random? random})
    : _random = random ?? math.Random();

  final math.Random _random;

  MathPuzzle next({
    MathPuzzleDifficulty difficulty = MathPuzzleDifficulty.medium,
  }) {
    switch (difficulty) {
      case MathPuzzleDifficulty.easy:
        return _addOrSubtract(maxOperand: 9);
      case MathPuzzleDifficulty.medium:
        // 70% add/sub, 30% multiplication with small operands.
        if (_random.nextDouble() < 0.7) {
          return _addOrSubtract(maxOperand: 50);
        }
        return _multiply(maxLeft: 9, maxRight: 9);
      case MathPuzzleDifficulty.hard:
        return _multiply(maxLeft: 25, maxRight: 12);
    }
  }

  MathPuzzle _addOrSubtract({required int maxOperand}) {
    final int a = _random.nextInt(maxOperand) + 1;
    final int b = _random.nextInt(maxOperand) + 1;
    final bool add = _random.nextBool();
    if (add) {
      return MathPuzzle(left: a, right: b, op: MathOp.add, answer: a + b);
    }
    // Ensure non-negative subtraction so the user never has to type a
    // minus sign in the middle of the night.
    final int high = math.max(a, b);
    final int low = math.min(a, b);
    return MathPuzzle(
      left: high,
      right: low,
      op: MathOp.subtract,
      answer: high - low,
    );
  }

  MathPuzzle _multiply({required int maxLeft, required int maxRight}) {
    final int a = _random.nextInt(maxLeft) + 2;
    final int b = _random.nextInt(maxRight) + 2;
    return MathPuzzle(left: a, right: b, op: MathOp.multiply, answer: a * b);
  }
}
