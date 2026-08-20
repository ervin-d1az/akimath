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

/// What pressing a key does, as a role rather than a colour.
///
/// **The design fills a key by what it does**: digits and the comma are white,
/// the operator strip is the accent, backspace is quiet and submit is the
/// action green. The pads shipped entirely white, which threw all four away —
/// and the only one a reader could have inferred from the glyph is the
/// backspace.
///
/// A role and not a `Color`, so this module stays what it is. The same split
/// `Verdict` uses: the pure type carries an outline and a glyph and no hue, and
/// the adapter beside it is the only thing that knows what green is.
enum KeyRole {
  /// A number or the decimal comma. White.
  digit,

  /// Something done *to* a number — the fraction bar, the sign, the power.
  /// The accent, because an operator is not a verdict and not the action.
  operator,

  /// Takes a character back. Quiet.
  erase,

  /// Sends the answer. The action green, and **one per pad** — *"en una
  /// pantalla solo un elemento lo lleva"*.
  commit,
}

/// One key.
class KeypadKey {
  const KeypadKey({
    required this.id,
    required this.face,
    this.emits,
    this.role = KeyRole.digit,
  });

  /// Stable identity, reported to the caller on press.
  final String id;

  final KeyFace face;

  /// The text this key contributes to an answer, when it contributes any.
  ///
  /// Null for keys that act rather than type — backspace, submit, enter. The
  /// keypad itself never assembles these into an answer; that rule lives with
  /// the contract, not on the client (design D4).
  final String? emits;

  /// What pressing it does, which is what the design fills it by.
  ///
  /// Defaults to [KeyRole.digit] because thirty of the thirty-eight keys across
  /// the three pads are digits, and declaring it on each would bury the six
  /// that are not.
  final KeyRole role;
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
      // **The operator strip is `a/b`, `−x`, `x²`, top to bottom**, which is
      // `TecladoReactivo`'s order and was not the code's — it ran `−x`, `x²`,
      // `a/b`, putting the only one of the three a player can currently use at
      // the bottom and a disabled key between two live ones.
      KeypadKey(id: '7', face: TextFace('7'), emits: '7'),
      KeypadKey(id: '8', face: TextFace('8'), emits: '8'),
      KeypadKey(id: '9', face: TextFace('9'), emits: '9'),
      KeypadKey(
        id: 'fraction',
        face: FractionFace(numerator: 'a', denominator: 'b'),
        emits: '/',
        role: KeyRole.operator,
      ),
      KeypadKey(id: '4', face: TextFace('4'), emits: '4'),
      KeypadKey(id: '5', face: TextFace('5'), emits: '5'),
      KeypadKey(id: '6', face: TextFace('6'), emits: '6'),
      KeypadKey(
        id: 'negate',
        face: TextFace(_negateFace),
        emits: _minus,
        role: KeyRole.operator,
      ),
      KeypadKey(id: '1', face: TextFace('1'), emits: '1'),
      KeypadKey(id: '2', face: TextFace('2'), emits: '2'),
      KeypadKey(id: '3', face: TextFace('3'), emits: '3'),
      KeypadKey(
        id: 'square',
        face: TextFace(_squareFace),
        emits: _squared,
        role: KeyRole.operator,
      ),
      KeypadKey(id: 'decimal', face: TextFace(_decimal), emits: _decimal),
      KeypadKey(id: '0', face: TextFace('0'), emits: '0'),
      KeypadKey(
        id: 'backspace',
        face: IconFace(BrandGlyph.backspace),
        role: KeyRole.erase,
      ),
      KeypadKey(
        id: 'submit',
        face: IconFace(BrandGlyph.submit),
        role: KeyRole.commit,
      ),
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
      KeypadKey(
        id: 'backspace',
        face: IconFace(BrandGlyph.backspace),
        role: KeyRole.erase,
      ),
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
      KeypadKey(
        id: 'backspace',
        face: IconFace(BrandGlyph.backspace),
        role: KeyRole.erase,
      ),
      KeypadKey(id: '0', face: TextFace('0'), emits: '0'),
      KeypadKey(
        id: 'enter',
        face: IconFace(BrandGlyph.submit),
        role: KeyRole.commit,
      ),
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

  /// **The faces carry the `x`, as the design draws them.**
  ///
  /// `TecladoReactivo` labels these two keys `−x` and `x²`. The code showed a
  /// bare `−` and a bare `²`, and in the brand's numeral face a lone superscript
  /// two sits in the fourth column reading as *another digit 2* — beside the
  /// real `2` one row down. The `x` is what says "this does something to your
  /// number" rather than "this is a number".
  static const String _negateFace = '−x';
  static const String _squareFace = 'x²';

  /// The keys whose output no answer can ever be.
  ///
  /// **`ANSWER_SHAPES` is `integer` and `fraction`** — the contract freezes
  /// both, and neither admits a decimal point or a power. `canonicalise('3,5')`
  /// and `canonicalise('5²')` both come back `non_numeric`, so pressing either
  /// key guarantees a wrong verdict no matter what the item asked.
  ///
  /// They stay on the pad because the design's grid is four by four and a hole
  /// in it is worse than a key that is visibly not offered — the same treatment
  /// a puzzle board already gives a digit above its ceiling. They come back the
  /// day the contract grows a shape that needs them.
  static const Set<String> keysWithNoGradableAnswer = <String>{
    'decimal',
    'square',
  };
}
