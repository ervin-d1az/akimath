/// The three numeric layouts, as data.
///
/// D14: there are three pads — item 4×4, puzzle 5×2, OTP 3×4 — and they *share*
/// one key. The first draft filed them as three adapters in three features,
/// which `components.md` calls the largest defect in plan §3; the concrete cost
/// is that the codepoint contract below gets re-typed three times, and R2 is
/// exactly that drift.
///
/// So the layouts are constants here and the widget is one. Nothing in this file
/// imports a widget or touches a `Canvas`.
library;

import '../../icons/spec/brand_glyph.dart';

/// What a key shows.
///
/// A sealed type rather than `String? label` plus `IconData? icon`, which would
/// make every renderer branch on which field is null and would make "both null"
/// and "both set" representable states nobody handles.
sealed class KeyFace {
  const KeyFace();
}

/// A digit or a symbol, set in the display face.
final class TextFace extends KeyFace {
  const TextFace(this.text);
  final String text;
}

/// A named glyph. The artwork arrives with the icon digests; the name does not
/// change when it does.
final class IconFace extends KeyFace {
  const IconFace(this.glyph);

  /// The glyph itself, typed.
  ///
  /// It was a `String`, on the stated grounds that "this module holds no widget
  /// import". A review disproved that in one line: `design/icons/spec/brand_glyph.dart`
  /// imports **nothing**, and `design/widgets/spec/verdict.dart` — a sibling pure
  /// module — already holds a `BrandGlyph` field. So the type costs no purity and
  /// the string bought nothing but a `firstWhere` in the adapter and a typo that
  /// only a pumped test would catch.
  final BrandGlyph glyph;
}

/// A stacked fraction, for the `a/b` key.
///
/// The digest describes it as pure geometry — `a` over a 20×3 bar over `b`, gap
/// 2 — with **no metric injection**, which is what made the `plain` variant
/// separable from the compositor in the first place (design D5).
final class FractionFace extends KeyFace {
  const FractionFace({required this.numerator, required this.denominator});
  final String numerator;
  final String denominator;
}

/// One key.
class KeypadKey {
  const KeypadKey({required this.id, required this.face, this.emits});

  /// Stable identity, reported to the caller on press.
  final String id;

  final KeyFace face;

  /// The text this key contributes to an answer, when it contributes any.
  ///
  /// Null for keys that act rather than type — backspace, submit, enter. The
  /// keypad itself never assembles these into an answer; that rule lives with
  /// the contract, not on the client (design D4).
  final String? emits;
}

/// A pad: an ordered list of keys and how many columns to wrap them into.
class KeypadLayout {
  const KeypadLayout({
    required this.name,
    required this.columns,
    required this.keys,
    required this.keyHeight,
    required this.gap,
    required this.iconSize,
  });

  final String name;
  final int columns;
  final List<KeypadKey> keys;

  /// Drawn key height. The item pad is h62 and the puzzle pad h58; the hit box
  /// clears 48 regardless, which `PressableSurface` guarantees.
  final double keyHeight;

  final double gap;

  /// Rendered glyph size. The backspace is one glyph at 24 here and 23 on the
  /// puzzle pad — one glyph, two sizes, never two named glyphs.
  final double iconSize;

  /// **Calculator order**: 7-8-9 on top.
  static const KeypadLayout item = KeypadLayout(
    name: 'item',
    columns: 4,
    keyHeight: 62,
    gap: 10,
    iconSize: 24,
    keys: <KeypadKey>[
      KeypadKey(id: '7', face: TextFace('7'), emits: '7'),
      KeypadKey(id: '8', face: TextFace('8'), emits: '8'),
      KeypadKey(id: '9', face: TextFace('9'), emits: '9'),
      KeypadKey(id: 'negate', face: TextFace(_minus), emits: _minus),
      KeypadKey(id: '4', face: TextFace('4'), emits: '4'),
      KeypadKey(id: '5', face: TextFace('5'), emits: '5'),
      KeypadKey(id: '6', face: TextFace('6'), emits: '6'),
      KeypadKey(id: 'square', face: TextFace(_squared), emits: _squared),
      KeypadKey(id: '1', face: TextFace('1'), emits: '1'),
      KeypadKey(id: '2', face: TextFace('2'), emits: '2'),
      KeypadKey(id: '3', face: TextFace('3'), emits: '3'),
      KeypadKey(
        id: 'fraction',
        face: FractionFace(numerator: 'a', denominator: 'b'),
        emits: '/',
      ),
      KeypadKey(id: 'decimal', face: TextFace(_decimal), emits: _decimal),
      KeypadKey(id: '0', face: TextFace('0'), emits: '0'),
      KeypadKey(id: 'backspace', face: IconFace(BrandGlyph.backspace)),
      KeypadKey(id: 'submit', face: IconFace(BrandGlyph.submit)),
    ],
  );

  /// **Reading order**: 1-2-3 on top. Deliberately different from [item], and
  /// the digest says not to unify them without a design decision (design D2).
  static const KeypadLayout puzzle = KeypadLayout(
    name: 'puzzle',
    columns: 5,
    keyHeight: 58,
    gap: 9,
    iconSize: 23,
    keys: <KeypadKey>[
      KeypadKey(id: '1', face: TextFace('1'), emits: '1'),
      KeypadKey(id: '2', face: TextFace('2'), emits: '2'),
      KeypadKey(id: '3', face: TextFace('3'), emits: '3'),
      KeypadKey(id: '4', face: TextFace('4'), emits: '4'),
      KeypadKey(id: '5', face: TextFace('5'), emits: '5'),
      KeypadKey(id: '6', face: TextFace('6'), emits: '6'),
      KeypadKey(id: '7', face: TextFace('7'), emits: '7'),
      KeypadKey(id: '8', face: TextFace('8'), emits: '8'),
      KeypadKey(id: '9', face: TextFace('9'), emits: '9'),
      KeypadKey(id: 'backspace', face: IconFace(BrandGlyph.backspace)),
    ],
  );

  /// The verification code pad.
  static const KeypadLayout otp = KeypadLayout(
    name: 'otp',
    columns: 3,
    keyHeight: 60,
    gap: 10,
    iconSize: 24,
    keys: <KeypadKey>[
      KeypadKey(id: '1', face: TextFace('1'), emits: '1'),
      KeypadKey(id: '2', face: TextFace('2'), emits: '2'),
      KeypadKey(id: '3', face: TextFace('3'), emits: '3'),
      KeypadKey(id: '4', face: TextFace('4'), emits: '4'),
      KeypadKey(id: '5', face: TextFace('5'), emits: '5'),
      KeypadKey(id: '6', face: TextFace('6'), emits: '6'),
      KeypadKey(id: '7', face: TextFace('7'), emits: '7'),
      KeypadKey(id: '8', face: TextFace('8'), emits: '8'),
      KeypadKey(id: '9', face: TextFace('9'), emits: '9'),
      KeypadKey(id: 'backspace', face: IconFace(BrandGlyph.backspace)),
      KeypadKey(id: '0', face: TextFace('0'), emits: '0'),
      KeypadKey(id: 'enter', face: IconFace(BrandGlyph.submit)),
    ],
  );

  static const List<KeypadLayout> all = <KeypadLayout>[item, puzzle, otp];

  /// Every key id any layout may declare.
  ///
  /// A closed union, asserted against, so a layout cannot introduce an id no
  /// consumer knows how to handle.
  static const Set<String> knownKeyIds = <String>{
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'negate', 'square', 'decimal', 'fraction',
    'backspace', 'submit', 'enter',
  };

  /// **U+2212 MINUS SIGN**, never U+002D HYPHEN-MINUS. The one place this is
  /// decided for the whole app's input path.
  static const String _minus = '−';

  /// U+00B2 SUPERSCRIPT TWO.
  static const String _squared = '²';

  /// U+002C COMMA — the es-MX decimal separator.
  static const String _decimal = ',';
}
