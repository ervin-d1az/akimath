import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/features/onboarding/policy/calibration.dart';
import 'package:flutter_test/flutter_test.dart';

/// A pack of [count] distinct arithmetic items, in a known order.
List<Item> _pack(int count) => <Item>[
      for (int index = 0; index < count; index++)
        Item(
          id: 'pack-$index',
          stimulus: ArithmeticStimulus(<PromptToken>[
            PromptToken.text('$index'),
            PromptToken.operator('+'),
            PromptToken.text('1'),
            PromptToken.operator('='),
          ]),
          answer: PlainAnswer('${index + 1}'),
          ladderStep: 1,
        ),
    ];

void main() {
  group('the probe asks ten at most', () {
    test('a long pack yields exactly ten, in pack order', () {
      final List<Item> plan = calibrationPlan(_pack(70));

      expect(plan, hasLength(calibrationLength));
      expect(
        plan.map((Item item) => item.id),
        <String>[for (int index = 0; index < 10; index++) 'pack-$index'],
      );
    });

    test('a pack shorter than ten yields what it holds', () {
      expect(calibrationPlan(_pack(4)), hasLength(4));
    });

    test('an empty pack yields nothing, and does not throw', () {
      expect(calibrationPlan(const <Item>[]), isEmpty);
    });

    test('no item is asked twice', () {
      final List<Item> plan = calibrationPlan(_pack(70));

      expect(plan.map((Item item) => item.id).toSet(), hasLength(plan.length));
    });
  });

  group('the bar says where you are, never how you are doing', () {
    test('one bar per planned item', () {
      expect(probeBarHeights(10), hasLength(10));
      expect(probeBarHeights(4), hasLength(4));
      expect(probeBarHeights(0), isEmpty);
    });

    test('the heights are the ones the design draws', () {
      expect(
        probeBarHeights(10),
        <double>[22, 16, 22, 14, 20, 14, 22, 16, 20, 14],
      );
    });

    test('and they are not all the same, which is the whole point', () {
      // `0.5` annotates the strip *"las alturas cambian: no es una serie, es
      // una sonda"*. A flat bar would read as a five-item series.
      expect(probeBarHeights(10).toSet().length, greaterThan(1));
    });

    test('a bar longer than the pattern keeps varying', () {
      // Nothing asks for more than ten today. A pattern that ran out would
      // return a short list and the strip would silently lose its last bars.
      expect(probeBarHeights(12), hasLength(12));
      expect(probeBarHeights(12).last, probeBarHeights(2).last);
    });
  });

  group('what the probe can honestly report', () {
    test('nothing answered is nothing to report', () {
      const CalibrationOutcome skipped = CalibrationOutcome(
        asked: 10,
        answered: 0,
        correct: 0,
        elapsed: Duration.zero,
      );

      expect(skipped.hasSomethingToReport, isFalse);
    });

    test('one answer is enough to report', () {
      const CalibrationOutcome partial = CalibrationOutcome(
        asked: 10,
        answered: 1,
        correct: 0,
        elapsed: Duration(seconds: 9),
      );

      expect(partial.hasSomethingToReport, isTrue);
      expect(partial.correct, 0);
    });

    test('an outcome carries what was answered, what was right and how long',
        () {
      const CalibrationOutcome outcome = CalibrationOutcome(
        asked: 10,
        answered: 6,
        correct: 4,
        elapsed: Duration(minutes: 2, seconds: 14),
      );

      expect(outcome.answered, 6);
      expect(outcome.correct, 4);
      expect(outcome.elapsed, const Duration(minutes: 2, seconds: 14));
    });

    test('two outcomes with the same figures are the same outcome', () {
      // A value type, so a widget test can assert on one without reaching
      // into its fields.
      const CalibrationOutcome one = CalibrationOutcome(
        asked: 10,
        answered: 6,
        correct: 4,
        elapsed: Duration(seconds: 30),
      );
      const CalibrationOutcome other = CalibrationOutcome(
        asked: 10,
        answered: 6,
        correct: 4,
        elapsed: Duration(seconds: 30),
      );

      expect(one, other);
    });
  });
}
