import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/features/round/policy/grading.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('a hyphen-minus is read as a minus sign', () {
      // The keypad cannot emit U+002D, but a future paste path or a fixture
      // written by hand can. Canonicalising here means the two never disagree.
      const Item negative = Item(
        id: 'demo-2',
        prompt: <PromptToken>[PromptToken.text('2 − 9')],
        expected: '−7',
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
  });
}
