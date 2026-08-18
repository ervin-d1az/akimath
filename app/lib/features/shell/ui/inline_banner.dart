import 'package:flutter/widgets.dart';

import '../../../design/icons/brand_icon.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../policy/banner_visual.dart';

/// A message across the top of a screen, or inline within it.
///
/// One widget and two skins — K7. The placement changes the radius and the
/// margin; it does not change what a banner *is*, and a second widget would
/// drift from the first on the parts that should never differ.
///
/// **It always draws a glyph**, because `resolveBannerVisual` always returns
/// one. That is the point: coral against yellow is the same unreadable pair
/// BRD-1 names, in a different widget.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.kind,
    required this.message,
    this.placement = BannerPlacement.inline,
    this.actionLabel,
    this.onAction,
  });

  final BannerKind kind;
  final String message;
  final BannerPlacement placement;

  /// An optional chip. Both must be given or neither.
  final String? actionLabel;
  final VoidCallback? onAction;

  Color get _background => switch (resolveBannerVisual(kind).tone) {
        BannerTone.error => BrandColorRole.error.color,
        BannerTone.notice => BrandColorRole.highlight.color,
      };

  @override
  Widget build(BuildContext context) {
    final BannerVisual visual = resolveBannerVisual(kind);
    final String? label = actionLabel;
    final VoidCallback? action = onAction;

    return CandySurface(
      background: _background,
      borderRadius: switch (placement) {
        BannerPlacement.inline => BrandShape.radiusChip,
        BannerPlacement.topBand => BrandShape.radiusPanel,
      },
      shadowOffset: BrandShape.shadowPill,
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space3,
        vertical: BrandShape.space2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 20 against the body text's 15: large enough to read as an icon
          // beside a sentence without becoming the loudest thing in the band.
          BrandIcon(visual.glyph, size: 20),
          const SizedBox(width: BrandShape.space2),
          Flexible(child: Text(message, style: BrandText.body())),
          if (label != null && action != null) ...<Widget>[
            const SizedBox(width: BrandShape.space2),
            BrandButton.text(label: label, onPressed: action),
          ],
        ],
      ),
    );
  }
}
