/// One challenge, as pure data.
///
/// This is the shape `f1b-content-reader` will produce from a bundled pack. It
/// exists now so the round can be played from an in-app fixture without the
/// screen learning a different type later — the reader replaces the *source*,
/// not the model.
library;

/// A piece of a rendered prompt.
///
/// **The prompt travels rendered** (`ARCHITECTURE.md` §4): the client is handed
/// what to draw, never a template and a seed to evaluate.
sealed class PromptToken {
  const PromptToken();

  const factory PromptToken.text(String value) = TextToken;
  const factory PromptToken.operator(String glyph) = OperatorToken;
  const factory PromptToken.fraction({
    required String numerator,
    required String denominator,
  }) = FractionToken;
}

final class TextToken extends PromptToken {
  const TextToken(this.value);
  final String value;
}

final class OperatorToken extends PromptToken {
  const OperatorToken(this.glyph);
  final String glyph;
}

final class FractionToken extends PromptToken {
  const FractionToken({required this.numerator, required this.denominator});
  final String numerator;
  final String denominator;
}

/// What an item asks, and therefore which renderer draws it.
///
/// **Sealed, so the seventh kind is a compile error away from being handled**
/// rather than a runtime surprise. `packages/contract` froze six kinds and the
/// app ships them one at a time; every `switch` over this type is exhaustive by
/// the analyzer, which is what makes adding a family a mechanical change
/// instead of a hunt for the places that needed updating.
sealed class Stimulus {
  const Stimulus();
}

/// `7 + 6 = ` — an expression with a blank at the end.
final class ArithmeticStimulus extends Stimulus {
  const ArithmeticStimulus(this.prompt);

  /// **The prompt travels rendered** (`ARCHITECTURE.md` §4): tokens to draw,
  /// never a template and a seed to evaluate.
  final List<PromptToken> prompt;
}

/// `2, 4, 6, 8, ?` — a run of terms with the next one missing.
final class NumberSeriesStimulus extends Stimulus {
  const NumberSeriesStimulus(this.terms);

  /// The terms shown, in order. The answer is what comes next, and it is *not*
  /// in this list — the blank is drawn by the renderer, so a pack cannot
  /// accidentally ship the answer on screen.
  final List<String> terms;
}

class Item {
  const Item({
    required this.id,
    required this.stimulus,
    required this.expected,
    required this.ladderStep,
  });

  final String id;

  /// What the item asks. One field, so there is one place to look.
  final Stimulus stimulus;

  /// The answer, in the canonical form `packages/contract` froze.
  ///
  /// Offline this travels with the item, which is what makes a verdict possible
  /// with no server — and provisional until sync, per the invariant.
  final String expected;

  /// Difficulty comes from the pack and is **never computed in Dart**.
  final int ladderStep;
}
