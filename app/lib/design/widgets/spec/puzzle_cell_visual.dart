import 'dart:ui' show Color;

// The one token file, not the barrel — a pure module reaching for `tokens.dart`
// pulls in `package:flutter/painting.dart` and fails `pure_boundary_test`.
import '../../tokens/brand_colors.dart';

/// What a cell is: something the puzzle blocked, something it supplied, or
/// something the player fills.
enum PuzzleCellKind { blocked, given, open }

/// How a cell is drawn.
///
/// **Three states told apart by fill *and* by whether they carry a value**
/// (BRD-1). Hue alone would make a blocked cell and an empty one the same thing
/// to a reader with deuteranopia — and on a board, mistaking one for the other
/// is not cosmetic, it is a cell they will try to fill forever.
class PuzzleCellVisual {
  const PuzzleCellVisual({
    required this.background,
    required this.ink,
    required this.selectable,
  });

  final Color background;
  final Color ink;

  /// Whether a player may put a value here at all.
  final bool selectable;
}

PuzzleCellVisual resolvePuzzleCell(PuzzleCellKind kind) => switch (kind) {
      // Inked solid: a wall, not an empty square waiting for something.
      PuzzleCellKind.blocked => const PuzzleCellVisual(
          background: BrandColors.ink,
          ink: BrandColors.ink,
          selectable: false,
        ),
      // Cream, the page colour — it reads as printed rather than entered.
      PuzzleCellKind.given => const PuzzleCellVisual(
          background: BrandColors.cream,
          ink: BrandColors.ink,
          selectable: false,
        ),
      PuzzleCellKind.open => const PuzzleCellVisual(
          background: BrandColors.surface,
          ink: BrandColors.ink,
          selectable: true,
        ),
    };
