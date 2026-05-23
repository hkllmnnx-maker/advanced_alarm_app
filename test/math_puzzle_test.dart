import 'dart:math' as math;

import 'package:advanced_alarm_app/ringing/services/math_puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MathPuzzle.isCorrect', () {
    const MathPuzzle puzzle = MathPuzzle(
      left: 12,
      right: 7,
      op: MathOp.add,
      answer: 19,
    );

    test('accepts the exact answer', () {
      expect(puzzle.isCorrect('19'), isTrue);
    });

    test('trims surrounding whitespace', () {
      expect(puzzle.isCorrect('  19  '), isTrue);
    });

    test('rejects wrong numbers', () {
      expect(puzzle.isCorrect('18'), isFalse);
      expect(puzzle.isCorrect('20'), isFalse);
    });

    test('rejects non-numeric input without throwing', () {
      expect(puzzle.isCorrect(''), isFalse);
      expect(puzzle.isCorrect('-'), isFalse);
      expect(puzzle.isCorrect('+'), isFalse);
      expect(puzzle.isCorrect('abc'), isFalse);
      expect(puzzle.isCorrect('19.0'), isFalse);
    });

    test('isCorrect handles negative answer puzzles', () {
      const MathPuzzle p = MathPuzzle(
        left: 3,
        right: 10,
        op: MathOp.subtract,
        answer: -7,
      );
      expect(p.isCorrect('-7'), isTrue);
      expect(p.isCorrect('7'), isFalse);
    });
  });

  group('MathPuzzleGenerator', () {
    test('every generated puzzle satisfies isCorrect on its own answer', () {
      // Use a seeded Random for deterministic coverage.
      final MathPuzzleGenerator gen = MathPuzzleGenerator(random: math.Random(42));
      for (int i = 0; i < 200; i++) {
        final MathPuzzle p = gen.next(
          difficulty: MathPuzzleDifficulty.values[i % 3],
        );
        expect(
          p.isCorrect(p.answer.toString()),
          isTrue,
          reason: 'generated puzzle should be self-consistent: $p',
        );
      }
    });

    test('easy difficulty never produces multiplication', () {
      final MathPuzzleGenerator gen = MathPuzzleGenerator(random: math.Random(1));
      for (int i = 0; i < 100; i++) {
        final MathPuzzle p = gen.next(difficulty: MathPuzzleDifficulty.easy);
        expect(p.op, isNot(MathOp.multiply));
      }
    });

    test('subtraction never returns a negative answer at medium difficulty', () {
      // Friendly UX: half-asleep users shouldn't have to type a minus sign.
      final MathPuzzleGenerator gen = MathPuzzleGenerator(random: math.Random(7));
      for (int i = 0; i < 200; i++) {
        final MathPuzzle p = gen.next(difficulty: MathPuzzleDifficulty.medium);
        if (p.op == MathOp.subtract) {
          expect(p.answer >= 0, isTrue, reason: 'subtraction produced negative: $p');
        }
      }
    });
  });
}
