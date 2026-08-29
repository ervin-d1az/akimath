import '../../../content/model/item.dart';
import '../../../design/math/spec/math_node.dart';

/// Turns a rendered prompt into a tree the compositor can lay out.
///
/// **This is a decision about what a drawing *is*, so it is not in the widget.**
/// It lived on `_RoundScreenState` until a review caught it: pure, but sitting
/// where proving it correct meant pumping a screen. The `FractionToken` arm in
/// particular — the only branch with structure — had no assertion anywhere,
/// because the tests that pump the round build their items from text and
/// operators, and the three gates that pump the registry's fraction item assert
/// blur, overflow and text decoration rather than tree shape.
///
/// **It takes tokens, not an `Item`.** There used to be a `nodeFor(Item)` in
/// front of this with a throwing `_promptOf` beneath it, back when the round
/// dispatched on the family itself. `StimulusView` owns that dispatch now and
/// hands over the tokens it has already destructured, so the wide entry point
/// had no caller in `lib/` and its throw had no test — an `Item`-shaped door
/// that looked live and led nowhere. Deleted in the change that gave the
/// authored pack one operator vocabulary.
///
/// Pure: tokens in, a node out. No widget, no `Canvas`, no context.
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
