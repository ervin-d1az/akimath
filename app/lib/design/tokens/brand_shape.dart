import 'dart:ui' show Offset;

/// Geometry of the "candy shop" direction: thick black outline and a hard
/// shadow with no blur. No widget invents its own stroke width or radius.
abstract final class BrandShape {
  /// Standard outline for cards, buttons, and pills.
  static const double borderWidth = 3;

  /// Outline for the app-icon tile, which is drawn far larger.
  static const double iconBorderWidth = 7;

  /// Outline for a small surface — a chip, a dot, a board cell — where the
  /// standard 3 would eat the fill. Named for the surface it outlines, like the
  /// radii below: a name ranking it against the other strokes would be false,
  /// because it is the thicker of the two that sit under `borderWidth`.
  static const double borderWidthSmallSurface = 2.5;

  /// Outline for a text field's resting state, which is quieter than a control
  /// the player can press.
  static const double borderWidthField = 2;

  /// A puzzle board's grid line — the thinnest stroke the app draws.
  ///
  /// `reactivos-puzzles.md`: *Celdas / 1.5 px tinta 18%*.
  static const double borderWidthHairline = 1.5;

  /// A cage's outline. Between the hairline and the board's own 3 px, because
  /// inside the board the hierarchy is colour and stroke rather than weight.
  ///
  /// `reactivos-puzzles.md`: *Jaula / 2.5 px punteado rosa*.
  static const double borderWidthCage = 2.5;

  /// Radii, named by the surface that carries them rather than by size, so a
  /// screen asks for a slot and not for a number. Two names may share a value
  /// — that is two roles, not a duplication.
  static const double radiusSlot = 12;

  /// The three stat-tile variants and the two stat-pill sizes.
  ///
  /// Named for their surfaces even though each shares a value with a radius
  /// above — that is two roles, not a duplication, and it is what lets a tile
  /// ask for a tile rather than borrow a button's number. They were literals in
  /// `stat_tile.dart` and `stat_pill.dart` until a review read BRD-2c against
  /// them; `no_geometry_literal_test` scans `Offset(` only, so a bare radius is
  /// exactly the case the rule reserves for a reader.
  static const double radiusStatTileRaised = 20;
  static const double radiusStatTileCompact = 18;
  static const double radiusStatTileFlat = 16;
  static const double radiusStatPillHeader = 24;
  static const double radiusStatPillHero = 22;
  static const double radiusChip = 14;
  static const double radiusControl = 16;
  static const double radiusPill = 18;
  static const double radiusButton = 20;
  static const double radiusIconTile = 20;
  static const double radiusCardSmall = 22;
  static const double radiusPanel = 24;
  static const double radiusCardMedium = 26;
  static const double radiusCard = 28;
  static const double radiusSheet = 32;
  static const double radiusScreen = 42;

  /// Hard-shadow offsets. Blur is ALWAYS zero — the visual system forbids a
  /// blurred shadow outright.
  static const Offset shadowDot = Offset(2, 3);
  static const Offset shadowPill = Offset(3, 4);
  static const Offset shadowTile = Offset(3, 5);

  /// The most common shadow in the app: cards, primary buttons, the bottom nav
  /// and the speech bubble all sit on this one.
  static const Offset shadowButton = Offset(4, 6);
  static const Offset shadowCard = Offset(5, 7);
  static const Offset shadowIcon = Offset(6, 8);

  /// Spacing scale.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 18;
  static const double space5 = 22;
  static const double space6 = 32;
  static const double space7 = 44;

  /// Minimum touch target. Applies to keypad keys and board cells alike.
  static const double minTouchTarget = 48;

  /// Minimum wordmark cap height. Below this Darumadrop loses its rounded
  /// terminal and stops reading as the mark.
  static const double minWordmarkFontSize = 28;
}
