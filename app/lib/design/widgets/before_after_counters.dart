import 'package:flutter/widgets.dart';

import '../icons/brand_icon.dart';
import '../tokens/tokens.dart';
import 'candy_surface.dart';

/// Two numbers with a page turned between them.
///
/// `Racha perdida` draws `13 › 1`. The **past is muted, flat and
/// shadowless; the present is yellow, outlined and raised** — and that contrast
/// is the whole argument of the screen, not a styling choice. Two identical
/// boxes would draw two equal facts, and one of them is over.
///
/// The pair is a `CandySurface` composition (design §4.3). Nothing here is a
/// primitive.
class BeforeAfterCounters extends StatelessWidget {
  const BeforeAfterCounters({
    super.key,
    required this.before,
    required this.beforeCaption,
    required this.after,
    required this.afterCaption,
  });

  final int before;
  final String beforeCaption;
  final int after;
  final String afterCaption;

  static const double _boxWidth = 82;
  static const double _boxHeight = 70;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _counter(
          value: before,
          caption: beforeCaption,
          background: BrandColors.surface,
          // Muted outline and no shadow: the box is behind glass.
          borderColor: BrandColors.muted,
          shadowOffset: Offset.zero,
          ink: BrandColors.muted,
        ),
        const SizedBox(width: BrandShape.space3),
        // **`mapsTo`, not `forward`.** The chevron's stand-in is `›`, and
        // `13 › 1` set between two numerals reads as `13 > 1` — true here by
        // accident and false the day the pair runs the other way. This glyph
        // means *becomes*, which is what happened.
        const BrandIcon(BrandGlyph.mapsTo, size: 24),
        const SizedBox(width: BrandShape.space3),
        _counter(
          value: after,
          caption: afterCaption,
          background: BrandColors.yellow,
          borderColor: BrandColors.ink,
          shadowOffset: BrandShape.shadowTile,
          ink: BrandColors.ink,
        ),
      ],
    );
  }

  Widget _counter({
    required int value,
    required String caption,
    required Color background,
    required Color borderColor,
    required Offset shadowOffset,
    required Color ink,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CandySurface(
          width: _boxWidth,
          height: _boxHeight,
          background: background,
          borderColor: borderColor,
          borderRadius: BrandShape.radiusButton,
          shadowOffset: shadowOffset,
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: BrandText.numeral(34).copyWith(color: ink),
          ),
        ),
        const SizedBox(height: BrandShape.space1),
        Text(
          caption,
          style: BrandText.eyebrow(color: ink, size: 10, letterSpacing: 0.06),
        ),
      ],
    );
  }
}
