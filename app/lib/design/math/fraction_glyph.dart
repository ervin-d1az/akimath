import 'package:flutter/widgets.dart';

import 'math_view.dart';
import 'spec/math_node.dart';

/// A stacked fraction of two literal runs.
///
/// A convenience over [MathView] for the common case, which is two short digit
/// runs and nothing else — the `a/b` key face, a denominator slot, a fraction
/// inside a sentence. It earns its name by taking two strings where [MathView]
/// takes a tree.
///
/// Only the `plain` variant exists. The **struck** variant (`04 Error`'s
/// −16° bar) and the **editable slot** (dashed pink, r12) belong to the changes
/// that consume them, and the dashed one cannot be built at all until
/// `f0-dashed-border` lands — a solid stand-in shipped now is a widget that
/// gets rewritten rather than extended.
class FractionGlyph extends StatelessWidget {
  const FractionGlyph({
    super.key,
    required this.numerator,
    required this.denominator,
    this.size = MathView.defaultNumeral,
  });

  final String numerator;
  final String denominator;

  /// Nominal size. Text scaling is applied by [MathView].
  final double size;

  @override
  Widget build(BuildContext context) {
    return MathView(
      size: size,
      node: FractionNode(
        numerator: NumeralNode(numerator),
        denominator: NumeralNode(denominator),
      ),
    );
  }
}
