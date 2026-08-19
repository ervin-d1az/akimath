import 'package:akimath_app/content/model/canon.dart';
import 'package:akimath_app/design/widgets/spec/keypad_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Everything a key can put into the answer, by key id.
Map<String, String> _emitters() => <String, String>{
      for (final KeypadKey key in KeypadLayout.item.keys)
        if (key.emits != null) key.id: key.emits!,
    };

/// Whether the text a key emits can be part of *any* answer the grader accepts.
///
/// **Position matters, so several are tried.** A digit stands alone, unary
/// minus goes in front (`−5`), the fraction slash goes between (`5/2`). Asking
/// only "does `5x` parse" would call the fraction key a trap, which it is not.
bool _appearsInSomeGradableAnswer(String emits) {
  final List<String> contexts = <String>[
    emits,
    '$emits\u0035',
    '5$emits',
    '5${emits}2',
  ];
  return contexts.any(
    (String candidate) => canonicalise(candidate, mode: CanonMode.learner).ok,
  );
}

void main() {
  group('a key must be able to produce a gradable answer', () {
    test('every key the pad offers can appear in one', () {
      // The defect: `,` and `x²` were live keys, and `canonicalise` refuses
      // both — so pressing either guaranteed a wrong verdict whatever the item
      // had asked. A pad that invites input the grader cannot accept is a
      // trap, and it is silent.
      final List<String> traps = <String>[];
      for (final MapEntry<String, String> key in _emitters().entries) {
        if (KeypadLayout.keysWithNoGradableAnswer.contains(key.key)) {
          continue;
        }
        if (!_appearsInSomeGradableAnswer(key.value)) {
          traps.add('${key.key} emits "${key.value}"');
        }
      }

      expect(traps, isEmpty);
    });

    test('the two that cannot are the two named', () {
      // Named rather than merely excluded: a set that grew silently would let
      // the next trap through under cover of the first two.
      expect(KeypadLayout.keysWithNoGradableAnswer, <String>{'decimal', 'square'});
    });

    test('and they really are ungradable — this is not a superstition', () {
      // `ANSWER_SHAPES` is integer and fraction. Neither admits a decimal point
      // or a power, and this asserts it against the canonicaliser rather than
      // against the claim.
      for (final String id in KeypadLayout.keysWithNoGradableAnswer) {
        final String emits = _emitters()[id]!;
        expect(
          _appearsInSomeGradableAnswer(emits),
          isFalse,
          reason: '$id emits "$emits", which the grader now accepts — '
              'if a shape grew, take it off the list',
        );
      }
    });
  });

  group('the grid is the one the design draws', () {
    test('four rows of four, in TecladoReactivo\'s order', () {
      // The digest's table, transcribed. The fourth column is the operator
      // strip and the bottom row breaks the pattern; the code had the strip in
      // a different order, which put the only usable operator at the bottom.
      expect(
        KeypadLayout.item.keys.map((KeypadKey k) => k.id).toList(),
        <String>[
          '7', '8', '9', 'fraction',
          '4', '5', '6', 'negate',
          '1', '2', '3', 'square',
          'decimal', '0', 'backspace', 'submit',
        ],
      );
    });

    test('the live operator is not buried under the dead ones', () {
      // With `,` and `x²` unavailable, the strip's only working key should not
      // sit below both of them.
      final List<String> strip = <String>[
        for (final (int index, KeypadKey key) in KeypadLayout.item.keys.indexed)
          if (index % 4 == 3) key.id,
      ];
      final int fraction = strip.indexOf('fraction');
      for (final String dead in KeypadLayout.keysWithNoGradableAnswer) {
        final int at = strip.indexOf(dead);
        if (at != -1) {
          expect(fraction, lessThan(at), reason: '"$dead" sits above the fraction key');
        }
      }
    });
  });

  group('the operator faces say what they do', () {
    test('negate and square carry the x the design draws', () {
      // A lone superscript two in the fourth column reads as another digit 2,
      // one row above the real one. `TecladoReactivo` labels them `−x` and
      // `x²`; the `x` is what says "this does something to your number".
      final Map<String, String> faces = <String, String>{
        for (final KeypadKey key in KeypadLayout.item.keys)
          if (key.face case TextFace(:final String text)) key.id: text,
      };

      expect(faces['negate'], '−x');
      expect(faces['square'], 'x²');
    });

    test('no operator face is a bare digit', () {
      // The failure in one sentence: a key in the operator column that looks
      // like a number.
      const Set<String> operators = <String>{'negate', 'square', 'decimal'};
      for (final KeypadKey key in KeypadLayout.item.keys) {
        if (!operators.contains(key.id)) {
          continue;
        }
        if (key.face case TextFace(:final String text)) {
          expect(RegExp(r'^\d$').hasMatch(text), isFalse,
              reason: '${key.id} draws "$text"');
        }
      }
    });
  });
}
