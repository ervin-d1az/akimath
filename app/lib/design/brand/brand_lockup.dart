import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import '../widgets/candy_surface.dart';
import 'amby.dart';
import 'wordmark.dart';

/// The four approved ways to place the mark.
///
/// Anything outside this set is not the brand. In particular, Amby is only
/// allowed in [fullWithAmby] and [compactWithAmby] — splash, store listing, and
/// the app header — and never repeats next to the wordmark elsewhere.
enum BrandLockupVariant {
  /// Amby large, centered over the wordmark. Splash and stores.
  fullWithAmby,

  /// Wordmark plus descriptor. Documents and page footers.
  fullWithoutAmby,

  /// Face tile plus wordmark, laid out horizontally. App headers.
  compactWithAmby,

  /// Wordmark alone. Bars and email.
  compactWithoutAmby,
}

/// The AmbysMath lockups.
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
      BrandLockupVariant.fullWithAmby => _FullWithAmby(tone: tone, scale: scale),
      BrandLockupVariant.fullWithoutAmby =>
        _FullWithoutAmby(tone: tone, scale: scale),
      BrandLockupVariant.compactWithAmby =>
        _CompactWithAmby(tone: tone, scale: scale),
      BrandLockupVariant.compactWithoutAmby => AmbysMathWordmark(
          fontSize: 44 * scale,
          tone: tone,
        ),
    };
  }
}

class _FullWithAmby extends StatelessWidget {
  const _FullWithAmby({required this.tone, required this.scale});

  final WordmarkTone tone;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Amby(width: 230 * scale),
        SizedBox(height: BrandShape.space3 * scale),
        AmbysMathWordmark(fontSize: 76 * scale, tone: tone),
      ],
    );
  }
}

class _FullWithoutAmby extends StatelessWidget {
  const _FullWithoutAmby({required this.tone, required this.scale});

  final WordmarkTone tone;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AmbysMathWordmark(fontSize: 82 * scale, tone: tone),
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

class _CompactWithAmby extends StatelessWidget {
  const _CompactWithAmby({required this.tone, required this.scale});

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
          child: AmbyFace(width: tile * 58 / 64),
        ),
        SizedBox(width: BrandShape.space3 * scale),
        AmbysMathWordmark(fontSize: 40 * scale, tone: tone),
      ],
    );
  }
}
