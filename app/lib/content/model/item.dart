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

/// `2, ?, 18, 54` — a run of terms with one of them missing.
///
/// **The hole is a position, not the end.** `packages/contract` spells every
/// family that hides a tile the same way — the full run travels and
/// `unknown_index` says which one is blank — and this follows it rather than
/// inventing a second convention that a pack builder would then have to
/// translate. It is also the better puzzle: a hole in the middle asks the
/// learner to run the rule backwards.
final class NumberSeriesStimulus extends Stimulus {
  const NumberSeriesStimulus({required this.terms, required this.unknownIndex});

  /// Every term in order, **including the true value of the hidden one**.
  ///
  /// That value is on the device on purpose: offline grading needs it and so
  /// does the replay the error screen will draw. It does not contradict *the
  /// answer never travels* — that invariant is about the online item response
  /// (`ARCHITECTURE.md` §4), which carries a rendered prompt and no answer at
  /// all. What it does mean is that **the renderer must not draw
  /// `terms[unknownIndex]`**, and `number_series_view_test.dart` holds it to
  /// that.
  final List<String> terms;

  /// Which term is blank. Always a valid index into [terms].
  final int unknownIndex;
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
