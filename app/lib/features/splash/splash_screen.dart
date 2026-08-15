import 'package:flutter/material.dart';

import '../../design/brand/amby.dart';
import '../../design/brand/wordmark.dart';
import '../../design/tokens/tokens.dart';
import '../../design/widgets/loading_dots.dart';

/// The two approved splash treatments.
enum SplashVariant {
  /// Cream canvas with Amby standing over the wordmark.
  cream,

  /// Brand green with the face in a cream tile. "Math" turns white here,
  /// because two accent colors never appear at once.
  brandGreen,
}

/// The loading screen.
///
/// It renders no state and starts no work: whatever the app is waiting on is
/// decided elsewhere and this screen is handed the result. That keeps it a pure
/// function of its variant, which is what makes it a golden test away from
/// being verified.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.variant = SplashVariant.cream});

  final SplashVariant variant;

  @override
  Widget build(BuildContext context) {
    final bool onGreen = variant == SplashVariant.brandGreen;

    return Scaffold(
      backgroundColor: onGreen ? BrandColors.green : BrandColors.cream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (onGreen) const _FaceTile() else const Amby(width: 222),
            const SizedBox(height: BrandShape.space6 - BrandShape.space1),
            AmbysMathWordmark(
              fontSize: 62,
              tone: onGreen ? WordmarkTone.onBrandGreen : WordmarkTone.onLight,
            ),
            const SizedBox(height: BrandShape.space6 - BrandShape.space1),
            BrandDescriptor(
              color: onGreen ? BrandColors.ink : BrandColors.muted,
            ),
            const SizedBox(height: BrandShape.space7 - BrandShape.space2),
            const LoadingDots(),
          ],
        ),
      ),
    );
  }
}

/// The cream tile that carries the face on the green splash. Its radius is
/// larger than the standard tile because it is drawn at 260px.
class _FaceTile extends StatelessWidget {
  const _FaceTile();

  static const double _size = 260;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BrandColors.cream,
        borderRadius: BorderRadius.circular(60),
        border: Border.all(color: BrandColors.ink, width: 4),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: BrandColors.ink,
            offset: BrandShape.shadowCard,
            blurRadius: 0,
          ),
        ],
      ),
      child: const AmbyFace(width: 232),
    );
  }
}
