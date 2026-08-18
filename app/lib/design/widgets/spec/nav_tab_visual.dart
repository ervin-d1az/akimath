import 'dart:ui' show Color, FontWeight;

// The one token file, not the barrel — `tokens.dart` re-exports
// `brand_typography.dart`, which imports `package:flutter/painting.dart`, and a
// pure module reaching for the barrel fails `pure_boundary_test`.
import '../../tokens/brand_colors.dart';

/// How a navigation tab is drawn, selected or not.
///
/// **Two differences again** (BRD-1). The selected tab is inked *and* heavier;
/// hue alone would make the bar say nothing to a reader with deuteranopia — and
/// a navigation bar that cannot say where you are is worse than no bar.
///
/// PURE, and separate from the widget for the reason
/// `no_hue_by_comparison_test` exists: a colour picked by an inline conditional
/// scatters the meaning of a hue across the screens that draw it.
class NavTabVisual {
  const NavTabVisual({
    required this.mark,
    required this.weight,
    required this.showsDot,
  });

  final Color mark;
  final FontWeight weight;

  /// Whether the dot above the label is drawn.
  ///
  /// **Presence, which is the shape half of the distinction.** Ink against
  /// muted is a hue difference and BRD-1 does not accept one on its own; a dot
  /// that is either there or not survives with the hue gone entirely.
  final bool showsDot;
}

NavTabVisual resolveNavTab(bool selected) => selected
    ? const NavTabVisual(
        mark: BrandColors.ink,
        weight: FontWeight.w800,
        showsDot: true,
      )
    : const NavTabVisual(
        mark: BrandColors.muted,
        weight: FontWeight.w600,
        showsDot: false,
      );
