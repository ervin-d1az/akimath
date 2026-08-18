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

/// How a cell is drawn, given what it is and whether the player is on it.
///
/// **Selection changes the fill, and that is a fix rather than a preference.**
/// It used to be a ring alone, drawn in ink at 3 px — the same colour and all
/// but the same width as a cage's outline, on the same edges. A cell fully
/// enclosed by its cage was therefore *selectable with no visible selection at
/// all*, which is what a player reported. The ring is still drawn, inset, so
/// shape carries the state for a reader who cannot separate the hues (BRD-1);
/// the fill is what makes it visible across a board.
///
/// The yellow is the one `term_visual.dart` uses for the hole in a stimulus and
/// `word_search_screen.dart` for the letters under a finger — "this is the
/// thing you are working on", already spelled the same way twice.
PuzzleCellVisual resolvePuzzleCell(
  PuzzleCellKind kind, {
  bool selected = false,
}) {
  final PuzzleCellVisual base = _base(kind);
  // Only an open cell can be selected; a blocked or given one would be a
  // highlight on something a player cannot change.
  return selected && base.selectable
      ? PuzzleCellVisual(
          background: BrandColors.yellow,
          ink: base.ink,
          selectable: base.selectable,
        )
      : base;
}

PuzzleCellVisual _base(PuzzleCellKind kind) => switch (kind) {
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
