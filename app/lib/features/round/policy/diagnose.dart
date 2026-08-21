import '../../../content/model/canon.dart';
import '../../../content/model/diagnosis.dart';
import '../../../content/model/item.dart';
import '../../../design/widgets/spec/verdict.dart';

/// What to tell a player about the answer they gave.
///
/// **PURE.** Item, answer and the pack's fallback in; copy or null out. No
/// clock, no store, no screen.
///
/// **A correct answer gets nothing**, and the verdict is **handed in** rather
/// than re-decided. It used to call `grade` itself, on the sound ground that
/// two implementations of "is this right" is the drift that would let the
/// verdict screen say *Acierto* while explaining away a mistake underneath it.
/// Taking it as an argument is the same argument carried further: there is now
/// one decision, made once by the caller, and no second call that could
/// disagree.
///
/// It is also what lets this work for an issued pack. `grade` reads a plaintext
/// answer, and a digest item has none — the call threw a `StateError` the first
/// time one was played, which is exactly the loudness `Item.expected` was given
/// for.
///
/// **Every wrong answer gets something.** A distractor the item anticipated
/// wins; anything else falls back. That matters more than it sounds, because
/// most wrong answers are unanticipated — the shipped pack anticipates four
/// items of seventy — and an empty diagnosis would leave the screen as bare as
/// it was before any of this existed.
///
/// **Only the typed side is canonicalised, and that is a decision** (design
/// D3). Learner mode folds the keypad's U+2212 to the hyphen a content author
/// types, which is the difference that would otherwise make every distractor
/// dead. The authored key is *not* canonicalised here because it cannot need
/// it: `Pack.fromJson` refuses a key that is not already storage-canonical, by
/// name and at load. Canonicalising it again would be an identity nothing can
/// observe — the second half of a symmetry that reads well and does nothing.
Diagnosis? diagnose({
  required Item item,
  required String answer,
  required Verdict verdict,
  required Diagnosis fallback,
}) {
  if (verdict == Verdict.correct) {
    return null;
  }

  // Null when the canonicaliser refuses the input outright, which no key can
  // equal — so an unreadable answer falls through to the fallback rather than
  // needing a guard of its own.
  final String? typed = canonicalise(answer, mode: CanonMode.learner).value;
  return item.distractors[typed] ?? fallback;
}
