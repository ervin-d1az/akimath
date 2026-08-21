import 'package:akimath_app/content/model/diagnosis.dart';
import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/features/round/policy/diagnose.dart';
import 'package:akimath_app/content/answer_digest.dart';
import 'package:flutter_test/flutter_test.dart';

const Diagnosis _reversed = Diagnosis(
  steps: <String>[
    'Fíjate en cuál número va primero.',
    'Quita el segundo al primero, en ese orden.',
  ],
  explain: 'Al restar, el orden importa.',
);

const Diagnosis _fallback = Diagnosis(
  steps: <String>['Lee otra vez el reto, sin prisa.'],
  explain: 'Repasa el reto con calma.',
);

Item _item({Map<String, Diagnosis> distractors = const <String, Diagnosis>{}}) => Item(
      id: 'sub-1',
      // 26 − 17 = 9. Subtracting in the wrong order gives −9, which is the
      // distractor these tests are about.
      stimulus: const ArithmeticStimulus(<PromptToken>[
        PromptToken.text('26'),
        PromptToken.operator('−'),
        PromptToken.text('17'),
        PromptToken.operator('='),
      ]),
      answer: PlainAnswer('9'),
      ladderStep: 3,
      distractors: distractors,
    );

Diagnosis? _for(String answer, {Map<String, Diagnosis>? distractors}) {
  final Item item =
      _item(distractors: distractors ?? <String, Diagnosis>{'-9': _reversed});
  // **The verdict is handed in now**, so the helper computes it once with the
  // same function the round does. Nothing here can disagree with the screen.
  return diagnose(
    item: item,
    answer: answer,
    verdict: gradeItem(item, answer),
    fallback: _fallback,
  );
}

void main() {
  group('a wrong answer always gets something to read', () {
    test('an anticipated one gets its own steps', () {
      // A player who subtracted in the wrong order and one who mistyped should
      // not get the same screen.
      expect(_for('-9'), _reversed);
    });

    test('anything else gets the fallback', () {
      // The common case: the shipped pack carries distractors for a handful of
      // items, and an empty diagnosis would leave the screen as bare as it is
      // today.
      expect(_for('42'), _fallback);
    });

    test('an item carrying no distractors still gets the fallback', () {
      expect(_for('42', distractors: const <String, Diagnosis>{}), _fallback);
    });

    test('an unreadable answer gets the fallback rather than nothing', () {
      // `canonicalise` refuses `9,0` and `--` outright. A player who typed one
      // is still owed a screen.
      expect(_for('9,0'), _fallback);
      expect(_for('--'), _fallback);
    });
  });

  group('the keypad\'s minus and the author\'s are the same minus', () {
    test('a typed U+2212 matches a distractor authored with a hyphen', () {
      // **This is the whole reason both sides go through the canonicaliser.**
      // The keypad emits U+2212 and a content author types the ASCII hyphen on
      // their keyboard, so the two never meet as strings. Learner mode folds
      // the typographic minus; stored mode does not, which is exactly why the
      // authored side is canonicalised in stored mode and the typed side in
      // learner mode — the same pairing `grade` uses.
      expect(_for('−9'), _reversed);
      expect(_for('-9'), _reversed);
    });

    test('a different number does not match', () {
      expect(_for('90'), _fallback);
      expect(_for('-90'), _fallback);
    });

    test('a key that is not storage-canonical never matches', () {
      // The reader refuses such a pack at load, naming the item. This is the
      // consequence if one ever reached here: a dead key, and a player who
      // still gets the fallback rather than a screen with nothing on it.
      expect(
        _for('-9', distractors: <String, Diagnosis>{'- 9': _reversed}),
        _fallback,
      );
    });

    test('the lookup is by canonical value, not by the raw text', () {
      // A map keyed by what the player typed would miss every time the keypad
      // and the author spell the same number differently — which is always,
      // for a negative.
      expect(
        _for('−9', distractors: <String, Diagnosis>{'-9': _reversed}),
        _reversed,
      );
    });
  });

  group('there is nothing to explain about a right answer', () {
    test('the correct answer gets no diagnosis', () {
      expect(_for('9'), isNull);
    });

    test('a distractor that shadows the correct answer never wins', () {
      // It reuses `grade`, so it cannot disagree with the verdict the player
      // was just shown — two implementations of "is this right" is the drift
      // worth avoiding here. The reader refuses such a pack; this is the second
      // line of defence.
      expect(
        _for('9', distractors: <String, Diagnosis>{'9': _reversed}),
        isNull,
      );
    });
  });
}
