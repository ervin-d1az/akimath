import '../../../content/model/canon.dart';
import '../../../content/model/item.dart';
import '../../../design/widgets/spec/verdict.dart';

/// Whether [answer] solves [item].
///
/// Pure: two values in, a verdict out. No clock, no network, no storage.
///
/// **Both sides go through the frozen canonicaliser**, and that is the point.
/// The player's answer is read in learner mode — spaces folded, U+2212 folded to
/// `-`, leading zeros stripped — and the item's expected answer in stored mode,
/// which refuses anything that is not already canonical rather than quietly
/// fixing it. A fixture written with `007` is a broken fixture and says so, at
/// the moment it is graded, instead of grading correctly by accident.
///
/// An answer the canonicaliser refuses is **wrong, not an error**: `1/0` and
/// `x+1` are things a player can produce, and the round has no error state for
/// them (DR-K4).
///
/// Offline this is the whole of grading, and its verdict is **provisional until
/// sync** — `ARCHITECTURE.md` §4.
Verdict grade(Item item, String answer) {
  final CanonResult typed = canonicalise(answer, mode: CanonMode.learner);
  final CanonResult expected =
      canonicalise(item.expected, mode: CanonMode.stored);

  if (!typed.ok || !expected.ok) {
    return Verdict.wrong;
  }
  return typed.value == expected.value ? Verdict.correct : Verdict.wrong;
}
