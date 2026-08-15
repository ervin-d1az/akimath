import 'dart:ui' show Color;

/// The AmbysMath palette.
///
/// Source of truth: `AmbysMath Marca.dc.html` in the design project.
/// No color literal is written anywhere outside this file.
///
/// Brand invariants (see [BrandColorRole]):
/// - [coral] means error and nothing else.
/// - [green] means action and success and nothing else.
/// - [pink] is the brand accent; it never carries state.
abstract final class BrandColors {
  /// Outlines, primary text, and every hard shadow. Never lightened.
  static const Color ink = Color(0xFF1C1A2E);

  /// The canvas the app screens sit on.
  static const Color cream = Color(0xFFFFF0D4);

  /// A duller canvas for documents and background surfaces.
  static const Color sand = Color(0xFFEFE2CC);

  /// Raised surface: cards and sheets.
  static const Color surface = Color(0xFFFFFFFF);

  /// Brand accent: the "Math" half of the wordmark and Amby's gills.
  static const Color pink = Color(0xFFE85E92);

  /// Amby's face.
  static const Color pinkFace = Color(0xFFFFC9DC);

  /// Amby's body and tail.
  static const Color pinkBody = Color(0xFFFF9EC1);

  /// Action and success. Also the app icon background.
  static const Color green = Color(0xFF5ED6A4);

  /// Error. Used for nothing else.
  static const Color coral = Color(0xFFFF8A5B);

  /// Neutral highlight.
  static const Color yellow = Color(0xFFFFD447);

  /// Secondary text and descriptors.
  static const Color muted = Color(0xFF8A7FA8);
}

/// The semantic role of a color, which is what the rest of the app asks for.
///
/// This exists so the brand invariants are verifiable: a screen asks for "the
/// error color", not for "coral". Remapping is a brand decision made in one
/// place.
enum BrandColorRole {
  /// Outline and primary text.
  ink(BrandColors.ink),

  /// Screen canvas.
  canvas(BrandColors.cream),

  /// Raised surface.
  surface(BrandColors.surface),

  /// Primary action.
  action(BrandColors.green),

  /// Success. Shares its color with [action] by brand decision.
  success(BrandColors.green),

  /// Error.
  error(BrandColors.coral),

  /// Brand accent. Carries no state.
  accent(BrandColors.pink),

  /// Neutral highlight.
  highlight(BrandColors.yellow),

  /// Secondary text.
  secondaryText(BrandColors.muted);

  const BrandColorRole(this.color);

  final Color color;
}
