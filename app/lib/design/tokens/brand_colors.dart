import 'dart:ui' show Color;

/// The AkiMath palette.
///
/// Source of truth: `AkiMath Marca.dc.html` and `Aki Hoja de Personaje.dc.html` in the design project.
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

  /// Brand accent: the "Math" half of the wordmark and Aki's collar.
  static const Color pink = Color(0xFFE85E92);

  /// The bead and facets on Aki's collar tag.
  static const Color pinkSoft = Color(0xFFFFC2D8);

  /// Figures drawn in pink: the hidden-operation machine's body and a figurate
  /// dot. A shade deeper than [pinkSoft], which stays the collar tag's.
  static const Color pinkFigure = Color(0xFFFF9EC1);

  /// Aki's coat. Also the color her mouth is cut into the dark muzzle with.
  static const Color akiCoat = Color(0xFFF7DFB6);

  /// Aki's muzzle. Dark enough to give the face contrast with itself, which is
  /// what keeps the app icon readable at 40px.
  static const Color akiMuzzle = Color(0xFF4A4060);

  /// Aki's ears, a shade darker than the muzzle.
  static const Color akiEars = Color(0xFF332B44);

  /// Action and success. Also the app icon background.
  static const Color green = Color(0xFF5ED6A4);

  /// Error. Used for nothing else.
  static const Color coral = Color(0xFFFF8A5B);

  /// Neutral highlight.
  static const Color yellow = Color(0xFFFFD447);

  /// Secondary text and descriptors.
  static const Color muted = Color(0xFF8A7FA8);

  /// The grid inside a puzzle board: ink at 18 %, a step above [rule] because
  /// a board draws a hundred of these and a card draws two — the same alpha
  /// reads as heavier on the board and lighter on the card.
  ///
  /// **`reactivos-puzzles.md` reserves the thick outline for the object.** Its
  /// own words: *"El contorno grueso se reserva para el objeto (el tablero).
  /// Dentro, la jerarquía deja de ser grosor y pasa a ser peso, color y
  /// trazo."* So a board's frame is 3 px ink, and everything inside it steps
  /// down — cells to a 1.5 px hairline at this opacity, cages to dashed pink.
  ///
  /// **There was a second token for this**, `hairline`, byte-identical and with
  /// a doc comment describing the same board rule in other words. It had no
  /// production caller and it was the one `brand_colors_test.dart` asserted
  /// against, so the alpha of the line both boards actually draw could be moved
  /// onto the card rule's with the whole suite green — measured, not supposed.
  static const Color gridHairline = Color(0x2E1C1A2E);

  /// A hairline divider inside a card. Ink at 16%, never a separate grey.
  static const Color rule = Color(0x291C1A2E);

  /// The quiet neutral: the backspace key's fill and a skeleton block's fill.
  /// It is the one surface that must read as present but not as offered.
  static const Color quiet = Color(0xFFEAE6F0);
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

  /// The field, key or cell the player is on right now. Transient input
  /// affordance, never a verdict: it says "here", not "right" or "wrong".
  focus(BrandColors.pink),

  /// Neutral highlight.
  highlight(BrandColors.yellow),

  /// Secondary text.
  secondaryText(BrandColors.muted);

  const BrandColorRole(this.color);

  final Color color;
}
