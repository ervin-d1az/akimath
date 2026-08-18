import 'package:flutter/painting.dart';

import 'brand_colors.dart';

/// The only two families the brand uses.
///
/// The files live in `assets/fonts/` and are declared in `pubspec.yaml`. They
/// are never fetched at runtime: the app is used by minors and cannot depend on
/// a third-party request to render text.
abstract final class BrandFonts {
  /// Display face. It carries the wordmark, section headers, and every figure
  /// the player reads as a quantity: keypad digits, board digits, stat values
  /// and OTP digits.
  ///
  /// It is never the "RETOS MATEMÁTICOS" descriptor, which is Plus Jakarta.
  static const String display = 'Darumadrop One';

  /// UI text. Variable font: weight is requested via [FontVariation].
  static const String text = 'Plus Jakarta Sans';
}

/// The brand's text styles.
///
/// Plus Jakarta Sans is a variable font, so every style declares its weight
/// twice: [TextStyle.fontWeight] for matching and semantics, and
/// [TextStyle.fontVariations] so the `wght` axis actually moves. Declaring
/// `fontWeight` alone always renders the default instance.
abstract final class BrandText {
  static TextStyle _text(
    double size,
    FontWeight weight, {
    Color color = BrandColors.ink,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: BrandFonts.text,
      fontSize: size,
      fontWeight: weight,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight.value.toDouble()),
      ],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle _display(
    double size, {
    Color color = BrandColors.ink,
    double? height,
  }) {
    return TextStyle(
      fontFamily: BrandFonts.display,
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color,
      height: height,
    );
  }

  /// Section header set in Darumadrop.
  static TextStyle sectionTitle({double size = 34}) => _display(size, height: 1);

  /// A digit the player reads as a quantity: a keypad key, a board cell, a
  /// stat value, an OTP box.
  ///
  /// It returns the same style as [sectionTitle] today and is a separate name
  /// on purpose — a keypad key reaching for "section title" is how a header
  /// tweak silently resizes the keypad.
  static TextStyle numeral(double size) => _display(size, height: 1);

  /// The wordmark. Call sites choose the size; it never goes below
  /// [BrandShape.minWordmarkFontSize].
  static TextStyle wordmark(double size, Color color) =>
      _display(size, color: color, height: 1);

  /// The descriptor under the wordmark. Plus Jakarta with heavy tracking.
  static TextStyle descriptor({
    double size = 12,
    Color color = BrandColors.muted,
  }) =>
      _text(size, FontWeight.w800, color: color, letterSpacing: size * 0.22);

  /// Small all-caps block label.
  ///
  /// [letterSpacing] is em and is resolved against [size], which is how the
  /// design documents state tracking and how [descriptor] already reads it.
  /// Asking for it in logical pixels would make every call site do the
  /// multiplication and would silently mistrack the day a size moved.
  static TextStyle eyebrow({
    Color color = BrandColors.muted,
    double size = 12,
    double letterSpacing = 0.1,
  }) =>
      _text(
        size,
        FontWeight.w800,
        color: color,
        letterSpacing: size * letterSpacing,
      );

  /// Card title.
  static TextStyle cardTitle({
    Color color = BrandColors.ink,
    double size = 20,
  }) =>
      _text(size, FontWeight.w800, color: color);

  /// Body copy. [height] tightens for a short line that has to sit in a box.
  static TextStyle body({
    Color color = BrandColors.ink,
    double height = 1.5,
  }) =>
      _text(15, FontWeight.w600, color: color, height: height);

  /// Secondary note.
  static TextStyle caption({
    Color color = BrandColors.muted,
    double size = 13,
    double height = 1.5,
  }) =>
      _text(size, FontWeight.w600, color: color, height: height);

  /// Text sitting on a button or a key.
  static TextStyle action({Color color = BrandColors.ink, double size = 18}) =>
      _text(size, FontWeight.w800, color: color);
}
