import 'package:akimath_app/features/round/policy/answer_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a draft accumulates what was typed', () {
    test('digits append in order', () {
      AnswerDraft draft = AnswerDraft.empty;
      for (final String digit in <String>['2', '3']) {
        draft = draft.type(digit);
      }
      expect(draft.text, '23');
    });

    test('backspace removes one character and stops at empty', () {
      AnswerDraft draft = AnswerDraft.empty.type('4').type('7');
      expect(draft.backspace().text, '4');
      expect(draft.backspace().backspace().text, '');
      expect(
        draft.backspace().backspace().backspace().text,
        '',
        reason: 'backspacing an empty draft must not throw or wrap',
      );
    });

    test('the draft is a value, not a mutable buffer', () {
      const AnswerDraft start = AnswerDraft.empty;
      final AnswerDraft after = start.type('5');

      expect(start.text, '');
      expect(after.text, '5');
    });
  });

  group('the draft holds the codepoint contract it was given', () {
    test('a minus sign is stored as U+2212, never a hyphen', () {
      final AnswerDraft draft = AnswerDraft.empty.type('−').type('6');
      expect(draft.text.codeUnitAt(0), 0x2212);
      expect(draft.text, isNot(contains('-')));
    });

    test('a decimal comma is stored as typed', () {
      expect(AnswerDraft.empty.type('4').type(',').type('2').text, '4,2');
    });
  });

  group('what a draft refuses', () {
    test('a second decimal separator is ignored', () {
      final AnswerDraft draft =
          AnswerDraft.empty.type('4').type(',').type('2').type(',');
      expect(draft.text, '4,2');
    });

    test('a minus is only accepted in the leading position', () {
      expect(AnswerDraft.empty.type('5').type('−').text, '5');
      expect(AnswerDraft.empty.type('−').type('5').text, '−5');
    });

    test('a draft has a length ceiling', () {
      AnswerDraft draft = AnswerDraft.empty;
      for (int i = 0; i < 40; i++) {
        draft = draft.type('9');
      }
      // Without a ceiling a child holding a key fills the slot until it
      // overflows the screen the overflow gate is meant to protect.
      expect(draft.text.length, AnswerDraft.maxLength);
    });
  });

  group('submitting', () {
    test('an empty draft cannot be submitted', () {
      expect(AnswerDraft.empty.canSubmit, isFalse);
      expect(AnswerDraft.empty.type('7').canSubmit, isTrue);
    });

    test('a draft that is only a minus sign cannot be submitted', () {
      expect(AnswerDraft.empty.type('−').canSubmit, isFalse);
    });
  });
}
