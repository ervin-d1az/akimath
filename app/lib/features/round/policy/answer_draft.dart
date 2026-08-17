/// What the player has typed so far.
///
/// Pure and immutable: every edit returns a new draft. It reads no clock, no
/// keypad and no widget — the keypad reports a key, the screen hands the
/// character here, and this decides what the answer text becomes.
///
/// **It does not decide whether an answer is correct.** That is [Grading]'s
/// job, and the separation matters: `ARCHITECTURE.md` §4 keeps the answer off
/// the wire and `packages/contract` froze what a canonical answer is.
library;

class AnswerDraft {
  const AnswerDraft(this.text);

  static const AnswerDraft empty = AnswerDraft('');

  /// Long enough for anything the corpus asks for, short enough that a child
  /// holding a key cannot overflow the slot the overflow gate protects.
  static const int maxLength = 12;

  /// U+2212 MINUS SIGN. Never U+002D — the keypad emits this and the draft
  /// stores exactly what it was given.
  static const String minusSign = '−';

  /// U+002C, the es-MX decimal separator.
  static const String decimalSeparator = ',';

  final String text;

  /// Appends [character], if the result is still a well-formed number.
  ///
  /// Refusals are silent by design: no document specifies feedback for an
  /// illegal keypress, and inventing a shake or a tone here would be inventing
  /// a design (DR-K4).
  AnswerDraft type(String character) {
    if (text.length >= maxLength) {
      return this;
    }
    if (character == decimalSeparator && text.contains(decimalSeparator)) {
      return this;
    }
    if (character == minusSign && text.isNotEmpty) {
      // A minus is a sign, not an operator: it means something only in front.
      return this;
    }
    return AnswerDraft('$text$character');
  }

  AnswerDraft backspace() =>
      text.isEmpty ? this : AnswerDraft(text.substring(0, text.length - 1));

  /// Whether there is an answer here to submit.
  ///
  /// A lone minus sign is not one — it is a sign with nothing after it.
  bool get canSubmit => text.isNotEmpty && text != minusSign;
}
