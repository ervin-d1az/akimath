import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';

/// A content-shaped placeholder.
///
/// **Never a spinner.** `Cargando` is annotated *esqueletos, sin ruedita*,
/// and `LoadingDots` is explicitly not to be repurposed for a product screen.
/// A skeleton says *what is coming* and where; a spinner says only *wait*.
///
/// It carries no animation. A shimmer is motion, and motion is F8.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    this.radius = BrandShape.radiusChip,
  });

  /// A block shaped like a line of text at [fontSize].
  const SkeletonBlock.line({
    Key? key,
    required double width,
    double fontSize = 15,
  })  // 6 rather than the block's radiusChip: a line of text is thin, and a
      // 14px radius on a 15px-tall box draws a lozenge rather than a line.
      : this(key: key, width: width, height: fontSize, radius: 6);

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: BrandColors.quiet,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
