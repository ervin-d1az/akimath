/// What a puzzle cage looks like, as pure data.
library;

// `dart:ui`'s `Color` is a value type with no rendering attached, and the one
// token file rather than the barrel — a pure module reaching for `tokens.dart`
// pulls in `package:flutter/painting.dart` and fails `pure_boundary_test`.
import 'dart:ui' show Color;

import '../../painting/spec/dash_spec.dart';
import '../../tokens/brand_colors.dart';
import '../../tokens/brand_shape.dart';

/// The dashed outline a puzzle cage carries, one constant per format.
///
/// **This is the one place a cage's appearance is decided.** It was not: the
/// dash, the stroke and the colour were named at each of the two widgets that
/// paint a cage, so [killer] reached no screen and a Killer board drew the
/// KenKen dash — while a test certifying its round cap read this file and
/// passed. A call site now asks for an outline and has no pattern of its own to
/// name, which is what makes a sixth format's dash a value somebody sets here
/// rather than a literal somebody forgets there.
///
/// The figures are the design's, from `reactivos-puzzles.md` by way of
/// `req-dashed-outline` in
/// `openspec/changes/archive/2026-08-26-f0-dashed-border`: KenKen `6 4` at
/// 2.5 px pink, Killer `2 5` round-capped, which reads as dots rather than
/// dashes.
///
/// **The radius and inset that document also records are deliberately not
/// here.** They describe a rounded rectangle drawn around a whole cage — rx 10
/// / inset 5 for KenKen, rx 9 / inset 6 for Killer — and
/// `fix-cage-outline-is-the-boards-weight` (D1) replaced that model with a path
/// of only the sides on the boundary, because a rounded rectangle per cell
/// draws a line through the middle of every multi-cell cage. Carrying two
/// numbers no painter can read is this file's own defect one size smaller; the
/// figures stay recoverable in that archived spec if the rounded model returns.
///
/// **And its third assertion — *"neither overlaps the 1.5 px hairline
/// beneath it"* — is retracted rather than moved, because it is false of the
/// model that shipped.** It was arithmetic on the two dropped figures,
/// `inset − strokeWidth / 2 > 0.75`, and the per-edge painter insets by
/// `strokeWidth / 2` exactly: the stroke's outer edge lands at 0.0 from the
/// cell's edge, `Border.all(borderWidthHairline)` occupies 0.0 to 1.5 inward,
/// so the same arithmetic now reads `0 > 0.75` and the cage covers the hairline
/// on every side it is on. That is the drawing the boards have shipped since
/// the per-edge painter landed, and it is what a cage *should* do — it is the
/// heavier line of the two. Deleting the assertion without writing this down
/// would leave `docs/IMPLEMENTATION-PLAN.md` and the archived spec asserting a
/// property nothing holds anyone to.
class CageOutline {
  const CageOutline({
    required this.dash,
    required this.color,
    required this.strokeWidth,
  });

  static const CageOutline kenKen = CageOutline(
    dash: DashSpec.kenKenCage,
    color: BrandColors.pink,
    strokeWidth: BrandShape.borderWidthCage,
  );

  static const CageOutline killer = CageOutline(
    dash: DashSpec.killerCage,
    color: BrandColors.pink,
    strokeWidth: BrandShape.borderWidthCage,
  );

  final DashSpec dash;
  final Color color;
  final double strokeWidth;

  /// The same cage, drawn on a reference diagram.
  ///
  /// A diagram is a 76 px board of nine cells, so the board's own 2.5 px would
  /// be a tenth of a cell wide. It steps down to the hairline the diagram rules
  /// its cells with and keeps the pattern and the colour, because the picture
  /// is about the cage on the board the player is looking at — a diagram that
  /// changed the dash would be teaching a format that does not exist.
  CageOutline get miniature => CageOutline(
        dash: dash,
        color: color,
        strokeWidth: BrandShape.borderWidthHairline,
      );

  /// Value equality, because [miniature] builds a new instance on every build
  /// and `CageEdgePainter.shouldRepaint` compares outlines. Identity there
  /// would repaint every diagram on every frame.
  ///
  /// `DashSpec` carries no `==`, so the dash is compared by identity. That
  /// holds for every outline reachable from here: the patterns are `static
  /// const`, Dart canonicalises those, and [miniature] passes the reference
  /// through unchanged.
  @override
  bool operator ==(Object other) =>
      other is CageOutline &&
      other.dash == dash &&
      other.color == color &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(dash, color, strokeWidth);

  /// Spelled out, so a failing expectation names the pattern that was drawn
  /// rather than reporting `Instance of 'CageOutline'` on both sides.
  @override
  String toString() => 'CageOutline(${dash.on} on / ${dash.off} off, '
      '${dash.cap.name} cap, ${strokeWidth}px)';
}
