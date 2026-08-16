import 'package:flutter/material.dart';

import '../../design/brand/aki.dart';
import '../../design/brand/wordmark.dart';
import '../../design/tokens/tokens.dart';
import '../../design/widgets/loading_dots.dart';

/// The two approved splash treatments.
enum SplashVariant {
  /// Cream canvas with Aki standing over the wordmark.
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

  /// One gap, used three times. The design spaces this column uniformly, and a
  /// single constant is what makes that structural rather than coincidental —
  /// three expressions over the spacing scale read as three decisions. It is
  /// not a scale entry: `BrandShape` governs recurring surfaces, and this is
  /// one screen's rhythm.
  static const double _gap = 26;

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
            if (onGreen) const _FaceTile() else const Aki(width: 210),
            const SizedBox(height: _gap),
            AkiMathWordmark(
              fontSize: 62,
              tone: onGreen ? WordmarkTone.onBrandGreen : WordmarkTone.onLight,
            ),
            const SizedBox(height: _gap),
            BrandDescriptor(
              color: onGreen ? BrandColors.ink : BrandColors.muted,
            ),
            const SizedBox(height: _gap),
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
        border: Border.all(
          color: BrandColors.ink,
          width: BrandShape.borderWidth,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: BrandColors.ink,
            offset: BrandShape.shadowCard,
            blurRadius: 0,
          ),
        ],
      ),
      child: const AkiFace(width: 232),
    );
  }
}
