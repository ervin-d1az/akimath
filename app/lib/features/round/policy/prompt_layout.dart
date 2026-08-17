import '../../../content/model/item.dart';
import '../../../design/math/spec/math_node.dart';

/// Turns an item's rendered prompt into a tree the compositor can lay out.
///
/// **This is a decision about what a drawing *is*, so it is not in the widget.**
/// It lived on `_RoundScreenState` until a review caught it: pure, but sitting
/// where proving it correct meant pumping a screen. The `FractionToken` arm in
/// particular — the only branch with structure — had no assertion anywhere,
/// because the tests that pump the round build their items from text and
/// operators, and the three gates that pump the registry's fraction item assert
/// blur, overflow and text decoration rather than tree shape.
///
/// Pure: an item in, a node out. No widget, no `Canvas`, no context.
MathNode nodeFor(Item item) => nodeForTokens(_promptOf(item));

/// The tokens an item draws, for the kinds that draw an expression.
///
/// Only arithmetic does. Every other family has its own renderer and does not
/// come through here — which the exhaustive switch makes true by construction
/// rather than by convention.
List<PromptToken> _promptOf(Item item) => switch (item.stimulus) {
      ArithmeticStimulus(:final List<PromptToken> prompt) => prompt,
      NumberSeriesStimulus() => throw ArgumentError(
          'a number series is not an expression; it has its own renderer',
        ),
    };

/// A row of tokens as a node tree.
MathNode nodeForTokens(List<PromptToken> tokens) {
  return RowNode(<MathNode>[
    for (final PromptToken token in tokens)
      switch (token) {
        TextToken(:final String value) => NumeralNode(value),
        OperatorToken(:final String glyph) => OperatorNode.of(glyph),
        FractionToken(:final String numerator, :final String denominator) =>
          FractionNode(
            numerator: NumeralNode(numerator),
            denominator: NumeralNode(denominator),
          ),
      },
  ]);
}
