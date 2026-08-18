import 'dart:ui' show Color;

import '../../painting/spec/dash_spec.dart';
import '../../tokens/brand_colors.dart';

/// What a term tile is: something the player was given, or the hole they fill.
///
/// A **named state** rather than a boolean resolved inline, because a hue chosen
/// by a comparison scatters the meaning of that hue across every screen that
/// draws one — and `no_hue_by_comparison_test` fails the build for it. Naming
/// the state puts the decision in one place and lets a test assert the pair is
/// distinguishable.
enum TermState {
  /// A term the series supplies.
  given,

  /// The term the player has to work out.
  unknown,
}

/// How a term tile is painted.
class TermVisual {
  const TermVisual({required this.background, required this.dash});

  final Color background;

  /// Null for a solid outline.
  final DashSpec? dash;
}

/// The one place a term's state becomes a paint.
///
/// **The outline carries the difference and the fill only reinforces it.**
/// BRD-1: deuteranopia collapses a good deal of this palette, so a state
/// communicated by hue alone is a state some readers cannot see. Dashed-versus-
/// solid survives with the colour stripped, which is the same reasoning that
/// gives the verdict ring a glyph as well as a hue.
TermVisual resolveTermVisual(TermState state) => switch (state) {
      TermState.given => const TermVisual(
          background: BrandColors.surface,
          dash: null,
        ),
      TermState.unknown => const TermVisual(
          background: BrandColors.yellow,
          dash: DashSpec.locked,
        ),
    };
