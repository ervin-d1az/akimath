/// The geometry of a puzzle cage's dashed outline, as pure data.
library;

// The barrel, not this file, is what would break purity: `tokens.dart`
// re-exports `brand_typography.dart`, which imports `package:flutter/painting.dart`.
// `brand_shape.dart` alone imports only `dart:ui show Offset`.
import '../../tokens/brand_shape.dart';
import 'dash_spec.dart';

/// The dashed outline a puzzle cage carries.
///
/// Cages are `f6-puzzles`, phases away. These numbers live here because they
/// are a property of the outline geometry and they are in the design digests
/// today — recorded where the geometry lives, so F6 consumes a tested figure
/// rather than re-deriving it from a mock six phases later (design D4).
///
/// **And they live in `spec/`, not beside the painter.** They were next to
/// `DashedBorderPainter`, in a file that imports `package:flutter/widgets.dart`
/// — const design geometry stranded on the wrong side of a boundary that file's
/// own doc comment states. The first pure cage-layout module to import them
/// would have failed the pure gate, which is the same collision `Verdict`
/// reaching for a glyph name already produced once in this repo. Moved before
/// F6 rather than after, so nobody meets it under time pressure.
class CageOutline {
  const CageOutline({
    required this.dash,
    required this.strokeWidth,
    required this.radius,
    required this.inset,
  });

  /// The rule drawn on a board's cell edges. A cage must clear it.
  static const double cellHairline = 1.5;

  static const CageOutline kenKen = CageOutline(
    dash: DashSpec.kenKenCage,
    strokeWidth: BrandShape.borderWidthSmallSurface,
    radius: 10,
    inset: 5,
  );

  static const CageOutline killer = CageOutline(
    dash: DashSpec.killerCage,
    strokeWidth: BrandShape.borderWidthSmallSurface,
    radius: 9,
    inset: 6,
  );

  final DashSpec dash;
  final double strokeWidth;
  final double radius;

  /// How far inside the cell block the outline sits.
  final double inset;
}
