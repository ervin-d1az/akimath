import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'pressable_surface.dart';

/// The square icon control: close, back, pause, undo, hint, pencil and gear.
///
/// **Seven controls, one widget.** They differ only in the glyph they hold and
/// whether they are toggled; a widget each would be seven files agreeing about
/// a radius. It is [PressableSurface] plus fixed geometry, so the press
/// behaviour is not restated here — it is inherited, which is the whole reason
/// the primitive exists.
///
/// It renders whatever it is handed and knows nothing about path data. The
/// glyphs are `f0-brand-icons`.
class IconButtonTile extends StatelessWidget {
  const IconButtonTile({
    super.key,
    required this.child,
    required this.onPressed,
    this.toggled = false,
  });

  /// The glyph.
  final Widget child;

  final VoidCallback onPressed;

  /// Whether the tile is in its active state. The fill is the **only**
  /// difference: geometry, travel and hit box are identical either way.
  final bool toggled;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onPressed: onPressed,
      width: BrandShape.minTouchTarget,
      height: BrandShape.minTouchTarget,
      borderRadius: BrandShape.radiusControl,
      shadow: BrandShape.shadowPill,
      background: toggled
          ? BrandColorRole.highlight.color
          : BrandColorRole.surface.color,
      child: Center(child: child),
    );
  }
}
