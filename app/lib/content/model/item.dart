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

class Item {
  const Item({
    required this.id,
    required this.prompt,
    required this.expected,
    required this.ladderStep,
  });

  final String id;
  final List<PromptToken> prompt;

  /// The answer, in the canonical form `packages/contract` froze.
  ///
  /// Offline this travels with the item, which is what makes a verdict possible
  /// with no server — and provisional until sync, per the invariant.
  final String expected;

  /// Difficulty comes from the pack and is **never computed in Dart**.
  final int ladderStep;
}
