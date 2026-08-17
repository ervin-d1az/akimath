import 'package:akimath_app/design/widgets/spec/keypad_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// U+2212 MINUS SIGN, U+00B2 SUPERSCRIPT TWO, U+002C COMMA.
const int minusSign = 0x2212;
const int superscriptTwo = 0x00B2;
const int comma = 0x002C;

void main() {
  group('the three layouts are the three the design draws', () {
    test('item is 4x4 in calculator order, ending , 0 backspace submit', () {
      const KeypadLayout item = KeypadLayout.item;

      expect(item.columns, 4);
      expect(item.keys, hasLength(16));

      // Calculator order: 7-8-9 on the top row. Asserted as the actual
      // sequence, because membership alone cannot tell the two orders apart —
      // and keeping them apart is the whole of design D2.
      expect(
        item.keys.take(3).map((KeypadKey k) => k.id).toList(),
        <String>['7', '8', '9'],
      );
      expect(
        item.keys.skip(12).map((KeypadKey k) => k.id).toList(),
        <String>['decimal', '0', 'backspace', 'submit'],
      );
    });

    test('puzzle is 5x2 in reading order, 1-9, no zero and no submit', () {
      const KeypadLayout puzzle = KeypadLayout.puzzle;

      expect(puzzle.columns, 5);
      expect(
        puzzle.keys.take(3).map((KeypadKey k) => k.id).toList(),
        <String>['1', '2', '3'],
        reason: 'the puzzle pad reads 1-2-3 across the top, not 7-8-9',
      );
      expect(puzzle.keys.map((KeypadKey k) => k.id), isNot(contains('0')));
      expect(puzzle.keys.map((KeypadKey k) => k.id), isNot(contains('submit')));
    });

    test('otp is 3x4 ending backspace 0 enter', () {
      const KeypadLayout otp = KeypadLayout.otp;

      expect(otp.columns, 3);
      expect(otp.keys, hasLength(12));
      expect(
        otp.keys.skip(9).map((KeypadKey k) => k.id).toList(),
        <String>['backspace', '0', 'enter'],
      );
    });

    test('the item and puzzle pads really do disagree on order', () {
      // Stated as its own assertion so that "unify them" fails loudly rather
      // than passing quietly. The digest says not to, without a design decision.
      expect(
        KeypadLayout.item.keys.first.id,
        isNot(KeypadLayout.puzzle.keys.first.id),
      );
    });
  });

  group('the codepoint contract is typed once', () {
    test('negate emits U+2212 and never a hyphen-minus', () {
      final KeypadKey negate = KeypadLayout.item.keys
          .firstWhere((KeypadKey k) => k.id == 'negate');

      expect(negate.emits!.codeUnitAt(0), minusSign);
      expect(negate.emits, isNot(contains('-')));
    });

    test('square emits U+00B2 and decimal emits U+002C', () {
      String emitsOf(String id) => KeypadLayout.item.keys
          .firstWhere((KeypadKey k) => k.id == id)
          .emits!;

      expect(emitsOf('square').codeUnitAt(0), superscriptTwo);
      expect(emitsOf('decimal').codeUnitAt(0), comma);
    });

    test('no layout declares an id outside the known union', () {
      final Set<String> declared = <String>{
        for (final KeypadLayout layout in KeypadLayout.all)
          ...layout.keys.map((KeypadKey k) => k.id),
      };

      expect(
        declared.difference(KeypadLayout.knownKeyIds),
        isEmpty,
        reason: 'a layout introduced a key id nothing else knows about',
      );
    });

    test('every emitting key across every layout avoids U+002D', () {
      for (final KeypadLayout layout in KeypadLayout.all) {
        for (final KeypadKey key in layout.keys) {
          expect(
            key.emits ?? '',
            isNot(contains('-')),
            reason: '${layout.name}/${key.id} emits a hyphen-minus',
          );
        }
      }
    });
  });

  group('a key face is not a nullable string', () {
    test('the a/b, 7 and backspace faces are three different types', () {
      KeyFace faceOf(KeypadLayout layout, String id) =>
          layout.keys.firstWhere((KeypadKey k) => k.id == id).face;

      expect(faceOf(KeypadLayout.item, 'fraction'), isA<FractionFace>());
      expect(faceOf(KeypadLayout.item, '7'), isA<TextFace>());
      expect(faceOf(KeypadLayout.item, 'backspace'), isA<IconFace>());
    });

    test('no key has a null face', () {
      // The encoding this rules out is `String? label` plus `IconData? icon`,
      // which makes "both null" and "both set" representable states nobody
      // handles (design D3).
      for (final KeypadLayout layout in KeypadLayout.all) {
        for (final KeypadKey key in layout.keys) {
          expect(key.face, isNotNull);
        }
      }
    });
  });
}
