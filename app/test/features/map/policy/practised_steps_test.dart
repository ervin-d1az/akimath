import 'package:akimath_app/features/map/policy/practised_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('practisedWith', () {
    test('records a family the record has never held', () {
      expect(
        practisedWith(const <String, int>{}, family: 'numberSeries', step: 2),
        <String, int>{'numberSeries': 2},
      );
    });

    test('keeps the harder step when a harder one arrives', () {
      expect(
        practisedWith(
          const <String, int>{'numberSeries': 2},
          family: 'numberSeries',
          step: 3,
        ),
        <String, int>{'numberSeries': 3},
      );
    });

    test('keeps the harder step when an easier one arrives', () {
      // A practice run that served step 1 after one that served step 3 must not
      // take progress away — the same rule `_Ladder.reached` keeps, for the
      // same reason: a player watching a topic go backwards for answering.
      expect(
        practisedWith(
          const <String, int>{'numberSeries': 3},
          family: 'numberSeries',
          step: 1,
        ),
        <String, int>{'numberSeries': 3},
      );
    });

    test('leaves every other family alone', () {
      expect(
        practisedWith(
          const <String, int>{'arithmetic': 4, 'numberSeries': 1},
          family: 'numberSeries',
          step: 2,
        ),
        <String, int>{'arithmetic': 4, 'numberSeries': 2},
      );
    });

    test('does not mutate the record it was handed', () {
      final Map<String, int> before = <String, int>{'arithmetic': 1};

      practisedWith(before, family: 'arithmetic', step: 5);

      expect(before, <String, int>{'arithmetic': 1});
    });

    test('ignores a step at or below zero rather than recording one', () {
      // `ladder_step` is one-based in every frozen pack, so zero is what a
      // corrupt row reads as — and zero means "never met", which is exactly
      // what an absent entry already says.
      expect(
        practisedWith(const <String, int>{}, family: 'matrix', step: 0),
        isEmpty,
      );
      expect(
        practisedWith(const <String, int>{}, family: 'matrix', step: -3),
        isEmpty,
      );
    });
  });

  group('readPractisedSteps', () {
    test('reads what was written', () {
      expect(
        readPractisedSteps(<String, Object?>{'numberSeries': 3}),
        <String, int>{'numberSeries': 3},
      );
    });

    test('drops a row that is not a positive whole step, and keeps the rest',
        () {
      // One unreadable entry costs one topic's practice history; refusing the
      // whole record would cost all six.
      expect(
        readPractisedSteps(<String, Object?>{
          'numberSeries': 3,
          'arithmetic': 'four',
          'matrix': 0,
          'analogy': -1,
          'figurate': 2.5,
        }),
        <String, int>{'numberSeries': 3},
      );
    });

    test('reads nothing out of nothing', () {
      expect(readPractisedSteps(const <String, Object?>{}), isEmpty);
    });
  });
}
