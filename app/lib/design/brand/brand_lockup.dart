import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import '../widgets/candy_surface.dart';
import 'aki.dart';
import 'wordmark.dart';

/// The four approved ways to place the mark.
///
/// Anything outside this set is not the brand. In particular, Aki is only
/// allowed in [fullWithAki] and [compactWithAki] — splash, store listing, and
/// the app header — and never repeats next to the wordmark elsewhere.
enum BrandLockupVariant {
  /// Aki large, centered over the wordmark. Splash and stores.
  fullWithAki,

  /// Wordmark plus descriptor. Documents and page footers.
  fullWithoutAki,

  /// Face tile plus wordmark, laid out horizontally. App headers.
  compactWithAki,

  /// Wordmark alone. Bars and email.
  compactWithoutAki,
}

/// The AkiMath lockups.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    required this.variant,
    this.tone = WordmarkTone.onLight,
    this.scale = 1,
  }) : assert(scale > 0, 'Scale must be positive.');

  final BrandLockupVariant variant;
  final WordmarkTone tone;

  /// Uniform multiplier over the variant's reference sizes. Shrinking far
  /// enough will trip the wordmark's minimum-size assert, which is the point.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      BrandLockupVariant.fullWithAki => _FullWithAki(tone: tone, scale: scale),
      BrandLockupVariant.fullWithoutAki =>
        _FullWithoutAki(tone: tone, scale: scale),
      BrandLockupVariant.compactWithAki =>
        _CompactWithAki(tone: tone, scale: scale),
      BrandLockupVariant.compactWithoutAki => AkiMathWordmark(
          fontSize: 44 * scale,
          tone: tone,
        ),
    };
  }
}

class _FullWithAki extends StatelessWidget {
  const _FullWithAki({required this.tone, required this.scale});

  final WordmarkTone tone;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Aki(width: 230 * scale),
        SizedBox(height: BrandShape.space3 * scale),
        AkiMathWordmark(fontSize: 76 * scale, tone: tone),
      ],
    );
  }
}

class _FullWithoutAki extends StatelessWidget {
  const _FullWithoutAki({required this.tone, required this.scale});

  final WordmarkTone tone;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AkiMathWordmark(fontSize: 82 * scale, tone: tone),
        SizedBox(height: BrandShape.space2 * scale),
        BrandDescriptor(
          fontSize: 15 * scale,
          color: tone == WordmarkTone.onBrandGreen
              ? BrandColors.ink
              : BrandColors.muted,
        ),
      ],
    );
  }
}

class _CompactWithAki extends StatelessWidget {
  const _CompactWithAki({required this.tone, required this.scale});

  final WordmarkTone tone;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double tile = 64 * scale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CandySurface.tile(
          size: tile,
          child: AkiFace(width: tile * 58 / 64),
        ),
        SizedBox(width: BrandShape.space3 * scale),
        AkiMathWordmark(fontSize: 40 * scale, tone: tone),
      ],
    );
  }
}
