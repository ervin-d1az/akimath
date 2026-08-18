import 'package:flutter/widgets.dart';

import '../../../../content/model/item.dart';
import '../../../../design/math/math_view.dart';
import '../../policy/prompt_layout.dart';
import 'analogy_view.dart';
import 'figurate_view.dart';
import 'hidden_operation_view.dart';
import 'matrix_view.dart';
import 'number_series_view.dart';

/// Draws whichever family a stimulus belongs to.
///
/// **One dispatch over the sealed type, for every screen that shows a
/// stimulus.** The round had the only copy and the home had none — it called
/// `nodeFor` directly, which throws on anything that is not an expression, so
/// the home crashed on launch for any pack whose first item was a series. That
/// was one reordering away from happening, and the reordering had already
/// happened for a different reason.
///
/// A second switch would have fixed the crash and left the real problem: two
/// places deciding what a matrix looks like, drifting a family at a time.
///
/// **Exhaustive**, so a seventh frozen kind is a compile error at the one site
/// that has to draw it rather than a screen that silently renders nothing.
class StimulusView extends StatelessWidget {
  const StimulusView({super.key, required this.stimulus, this.scaleDown = true});

  final Stimulus stimulus;

  /// Whether to shrink to fit. The round always does; a preview card sized by
  /// its own box may not want to.
  final bool scaleDown;

  @override
  Widget build(BuildContext context) {
    final Widget drawn = switch (stimulus) {
      ArithmeticStimulus(:final List<PromptToken> prompt) =>
        MathView(node: nodeForTokens(prompt)),
      NumberSeriesStimulus(:final List<int> terms, :final int unknownIndex) =>
        NumberSeriesView(terms: terms, unknownIndex: unknownIndex),
      MatrixStimulus(
        :final List<int> cells,
        :final int size,
        :final int unknownIndex
      ) =>
        MatrixView(cells: cells, size: size, unknownIndex: unknownIndex),
      AnalogyStimulus(:final List<int> terms, :final int unknownIndex) =>
        AnalogyView(terms: terms, unknownIndex: unknownIndex),
      HiddenOperationStimulus(
        :final List<({int input, int output})> examples,
        :final int queryInput
      ) =>
        HiddenOperationView(examples: examples, queryInput: queryInput),
      FigurateStimulus(:final List<int> dotCounts, :final int unknownIndex) =>
        FigurateView(dotCounts: dotCounts, unknownIndex: unknownIndex),
    };

    return scaleDown ? FittedBox(fit: BoxFit.scaleDown, child: drawn) : drawn;
  }
}
