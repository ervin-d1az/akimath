import 'package:flutter/widgets.dart';

import '../icons/brand_icon.dart';
import '../tokens/tokens.dart';
import 'pressable_surface.dart';

/// One row of a settings list: a label, an optional value, an optional chevron.
///
/// **The trailing is a slot and a flag, not an enum.** `4.2` draws three shapes
/// — a chevron, a value beside a chevron, and nothing at all on `Cerrar
/// sesión` — and `4.7` draws the same widget again. An enum would have to grow
/// for the fourth, and this widget has no reason to know what a value is.
///
/// **A chevron is a promise.** A row that acts in place rather than opening a
/// screen draws none, because the mark says *there is more through here* and a
/// player who presses it and stays put has been told something untrue.
///
/// It is a [PressableSurface], so the row travels into its own shadow like
/// everything else and the 48 px hit box comes free.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    required this.onOpen,
    this.value,
    this.showChevron = true,
  });

  final String label;
  final VoidCallback onOpen;

  /// What the row already says about itself — `4.2`'s `19:30`.
  final String? value;

  /// Whether pressing it opens a screen.
  final bool showChevron;

  /// The design's row height.
  static const double height = 62;

  @override
  Widget build(BuildContext context) {
    final String? trailing = value;

    return PressableSurface(
      onPressed: onOpen,
      minHeight: height,
      borderRadius: BrandShape.radiusButton,
      shadow: BrandShape.shadowTile,
      padding: const EdgeInsets.symmetric(horizontal: BrandShape.space4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: BrandText.cardTitle(size: 16))),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: BrandShape.space2),
            Text(trailing, style: BrandText.caption()),
          ],
          if (showChevron) ...<Widget>[
            const SizedBox(width: BrandShape.space3),
            const BrandIcon(BrandGlyph.forward, size: 20),
          ],
        ],
      ),
    );
  }
}
