import 'dart:ui' show Offset, Rect;

import '../../brand/spec/brand_shapes.dart';

/// The two marks the bottom bar needs, drawn here rather than transcribed.
///
/// **This is a fork of the design, and it is named as one.** `f0-brand-icons`'
/// rule D2 forbids redrawing a digest glyph by eye, because "an icon drawn from
/// memory is a fork of the design that nobody knows exists". The design does
/// draw four stroked nav glyphs; they are not transcribed, and the digests are
/// not reachable. So these two exist, they are *ours*, and
/// `test/design/icons/nav_glyph_spec_test.dart` counts them — the fork is
/// known, listed, and has somewhere to be deleted from.
///
/// They go when the digests land. Nothing else should use them: every other
/// glyph is still a stand-in character in `BrandIcon`, and adding a third
/// hand-drawn mark should feel like a decision rather than a habit.
///
/// **Why not the existing `gear` stand-in.** `BrandGlyph.gear` renders `⚙`,
/// which most systems paint as a colour emoji — in a bar whose entire palette
/// is two inks, that is the one mark guaranteed to look wrong. And `home` had
/// no stand-in at all; the nearest was `check`, which means *correct*
/// everywhere else in this app.
abstract final class NavGlyphSpec {
  /// A 24×24 box, the size `BrandIcon` is asked for almost everywhere.
  static const Rect viewBox = Rect.fromLTWH(0, 0, 24, 24);

  /// The stroke weight the brand's own marks carry at this size.
  ///
  /// Named once: two glyphs drawn at different weights in the same bar is the
  /// kind of thing nobody sees and everybody feels.
  static const double _weight = 2.4;

  /// A knob is heavier than its rail, or it reads as a crossing line.
  static const double _knob = 3.2;

  /// A house: a roof over a body, both open at the join.
  ///
  /// Drawn as two strokes rather than one closed outline so the roof's peak
  /// keeps its own cap — a single path corners it, and a cornered peak at 24 px
  /// reads as a blob.
  static final BrandDrawing home = BrandDrawing(
    viewBox: viewBox,
    marks: <BrandMark>[
      // The roof, eave to peak to eave.
      const InkStroke(
        start: Offset(3.5, 11),
        steps: <PathStep>[LineTo(Offset(12, 4)), LineTo(Offset(20.5, 11))],
        width: _weight,
      ),
      // The body, up one side, across the base, down the other. Open at the
      // top, where the roof already is.
      const InkStroke(
        start: Offset(6, 9.8),
        steps: <PathStep>[
          LineTo(Offset(6, 19.5)),
          LineTo(Offset(18, 19.5)),
          LineTo(Offset(18, 9.8)),
        ],
        width: _weight,
      ),
    ],
  );

  /// Two sliders: the settings mark that survives being small.
  ///
  /// **Not a cogwheel.** A gear at 20 px is eight teeth of about two pixels
  /// each, which at this stroke weight fills in solid. Sliders stay legible,
  /// and they are honestly *not* the design's gear rather than a poor copy of
  /// it — which is the distinction D2 protects.
  ///
  /// **Strokes only, no filled knobs.** `InkShape` outlines in `BrandColors.ink`
  /// and takes no colour, so a filled knob could not follow the tab's state
  /// while the rails did. A knob is a short, heavier cross-stroke instead.
  static final BrandDrawing settings = BrandDrawing(
    viewBox: viewBox,
    marks: <BrandMark>[
      // The upper rail, with its knob right of centre.
      InkStroke.line(const Offset(4, 8.5), const Offset(20, 8.5), width: _weight),
      InkStroke.line(const Offset(16, 5.6), const Offset(16, 11.4), width: _knob),
      // The lower rail, knob left of centre, so the pair is not one shape twice.
      InkStroke.line(const Offset(4, 15.5), const Offset(20, 15.5), width: _weight),
      InkStroke.line(const Offset(8, 12.6), const Offset(8, 18.4), width: _knob),
    ],
  );
}
