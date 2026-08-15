import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// Three outlined dots. That is the whole loading indicator.
///
/// The brand doc is explicit: no particles, no spinner, three dots and done.
/// They are deliberately static — motion during load competes with the mark.
class LoadingDots extends StatelessWidget {
  const LoadingDots({super.key, this.diameter = 14});

  final double diameter;

  /// Fixed order. These three read as one set; recoloring them breaks it.
  static const List<Color> colors = <Color>[
    BrandColors.pink,
    BrandColors.yellow,
    BrandColors.surface,
  ];

  @override
  Widget build(BuildContext context) {
    final double border = diameter * 2.5 / 14;

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < colors.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: diameter * 10 / 14),
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                color: colors[i],
                shape: BoxShape.circle,
                border: Border.all(color: BrandColors.ink, width: border),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
