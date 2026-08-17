import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/features/round/policy/grading.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every expected answer in the shipped fixture must be storage-canonical.
///
/// This caught a real one: `demo-4` was written `−7` with U+2212, which stored
/// mode refuses. It would have shown the player a wrong verdict for the right
/// answer, on a device, with no error anywhere.
const Item _threeQuarters = Item(
  id: 'demo-1',
  prompt: <PromptToken>[
    PromptToken.fraction(numerator: '3', denominator: '4'),
    PromptToken.operator('+'),
    PromptToken.fraction(numerator: '2', denominator: '4'),
  ],
  expected: '5/4',
  ladderStep: 3,
);

void main() {
  group('grading compares canonical forms', () {
    test('the expected answer is correct', () {
      expect(grade(_threeQuarters, '5/4'), Verdict.correct);
    });

    test('a different answer is wrong', () {
      expect(grade(_threeQuarters, '4/5'), Verdict.wrong);
    });

    test('surrounding whitespace does not change the verdict', () {
      expect(grade(_threeQuarters, ' 5/4 '), Verdict.correct);
    });

    test('leading zeros do not change the verdict', () {
      // The learner form strips them; the frozen fixture says 007 is 7.
      expect(grade(_threeQuarters, '05/4'), Verdict.correct);
    });

    test('a fraction is not reduced, so 10/8 is not 5/4', () {
      // Deliberate: deciding those are the same answer is a pedagogical call
      // the contract does not make.
      expect(grade(_threeQuarters, '10/8'), Verdict.wrong);
    });

    test('a hyphen-minus is read as a minus sign', () {
      // The keypad cannot emit U+002D, but a future paste path or a fixture
      // written by hand can. Canonicalising here means the two never disagree.
      // Storage is ASCII: `-7` is the canonical form and `−7` is not, which
      // stored mode refuses rather than quietly fixing. The keypad emits U+2212
      // and the learner form folds it, so both spellings grade correct from the
      // player's side — which is the whole shape of the contract.
      const Item negative = Item(
        id: 'demo-2',
        prompt: <PromptToken>[PromptToken.text('2 − 9')],
        expected: '-7',
        ladderStep: 1,
      );
      expect(grade(negative, '-7'), Verdict.correct);
      expect(grade(negative, '−7'), Verdict.correct);
    });
  });

  group('grading reads nothing but its arguments', () {
    test('the same call twice gives the same verdict', () {
      expect(grade(_threeQuarters, '5/4'), grade(_threeQuarters, '5/4'));
    });

    test('an empty answer is wrong rather than an error', () {
      expect(grade(_threeQuarters, ''), Verdict.wrong);
    });

    test('an unparseable answer is wrong rather than an error', () {
      // Things a player can actually produce. The round has no error state for
      // them, so they are simply not the answer (DR-K4).
      for (final String nonsense in <String>['1/0', 'x+1', '−']) {
        expect(grade(_threeQuarters, nonsense), Verdict.wrong);
      }
    });

    test('an expected answer that is not canonical never grades correct', () {
      // A fixture written with a non-canonical answer is broken, and it says so
      // at grading time rather than grading correctly by accident.
      const Item broken = Item(
        id: 'broken',
        prompt: <PromptToken>[PromptToken.text('1 + 1')],
        expected: ' 002 ',
        ladderStep: 1,
      );
      expect(grade(broken, '2'), Verdict.wrong);
    });
  });
}
