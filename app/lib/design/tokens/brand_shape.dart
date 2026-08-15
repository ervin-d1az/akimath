import 'dart:ui' show Offset;

/// Geometry of the "candy shop" direction: thick black outline and a hard
/// shadow with no blur. No widget invents its own stroke width or radius.
abstract final class BrandShape {
  /// Standard outline for cards, buttons, and pills.
  static const double borderWidth = 3;

  /// Outline for the app-icon tile, which is drawn far larger.
  static const double iconBorderWidth = 7;

  /// Radii. The scale is deliberately short.
  static const double radiusPill = 18;
  static const double radiusCard = 28;
  static const double radiusIconTile = 20;
  static const double radiusScreen = 42;

  /// Hard-shadow offsets. Blur is ALWAYS zero — the visual system forbids a
  /// blurred shadow outright.
  static const Offset shadowPill = Offset(3, 4);
  static const Offset shadowTile = Offset(3, 5);
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
