import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'amby.dart';

/// The two backgrounds the icon was explored on.
///
/// The brand doc settles this: green wins. Pink on cream is two light values,
/// so at icon size the head dissolves into the tile and only the eyes survive.
/// Green also keeps the icon distinct from the app itself — cream is the
/// canvas inside the app, green is the mark on the phone's home screen.
enum AppIconBackground {
  /// The one that ships.
  brandGreen(BrandColors.green),

  /// Kept for reference. Do not ship it.
  cream(BrandColors.cream);

  const AppIconBackground(this.color);

  final Color color;
}

/// The app icon: the face and the gills, no text.
///
/// Proportions come from the 1024×1024 master in the brand doc — 30px outline,
/// 230px corner radius — expressed as ratios so the icon is correct at any
/// size, from a 40px list row to the store asset.
///
/// Store caveat: iOS masks app icons with a superellipse whose radius is very
/// close to [_radiusRatio], so the designed outline lands exactly on the mask
/// edge and gets shaved. For the iOS export, either inset the whole composition
/// or drop the outline; on Android the adaptive-icon safe zone is tighter still.
/// Rendering inside the app is unaffected.
class AmbyAppIcon extends StatelessWidget {
  const AmbyAppIcon({
    super.key,
    required this.size,
    this.background = AppIconBackground.brandGreen,
    this.withShadow = true,
  }) : assert(size > 0, 'The icon needs a positive size.');

  /// Outer edge length of the tile.
  final double size;

  final AppIconBackground background;

  /// The hard shadow belongs to the icon as it appears inside the app. The
  /// exported store asset carries no shadow — the OS draws its own.
  final bool withShadow;

  static const double _borderRatio = 30 / 1024;
  static const double _radiusRatio = 230 / 1024;
  static const double _faceRatio = 214 / 240;

  @override
  Widget build(BuildContext context) {
    final double borderWidth = size * _borderRatio;
    final double radius = size * _radiusRatio;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background.color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: BrandColors.ink, width: borderWidth),
        boxShadow: withShadow
            ? <BoxShadow>[
                BoxShadow(
                  color: BrandColors.ink,
                  offset: Offset(size * 6 / 240, size * 8 / 240),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: AmbyFace(
        width: size * _faceRatio,
        semanticLabel: 'AmbysMath',
      ),
    );
  }
}
