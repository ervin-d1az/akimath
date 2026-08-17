import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/design/math/spec/math_node.dart';
import 'package:akimath_app/features/round/policy/prompt_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a prompt becomes a node tree', () {
    test('each token kind maps to its node', () {
      const Item item = Item(
        id: 'i',
        prompt: <PromptToken>[
          PromptToken.fraction(numerator: '3', denominator: '4'),
          PromptToken.operator('+'),
          PromptToken.text('1'),
        ],
        expected: '7/4',
        ladderStep: 1,
      );

      final RowNode row = nodeFor(item) as RowNode;

      expect(row.children, hasLength(3));
      expect(row.children[0], isA<FractionNode>());
      expect(row.children[1], isA<OperatorNode>());
      expect(row.children[2], isA<NumeralNode>());
    });

    test('a fraction keeps its numerator and denominator, in that order', () {
      // The branch with structure, and the one nothing asserted while this
      // lived on the widget: the round tests build items from text and
      // operators, and the gates that pump the registry's fraction item check
      // blur, overflow and text decoration rather than tree shape. A swapped
      // numerator would have rendered a different question with every test
      // green.
      const Item item = Item(
        id: 'i',
        prompt: <PromptToken>[
          PromptToken.fraction(numerator: '3', denominator: '4'),
        ],
        expected: '3/4',
        ladderStep: 1,
      );

      final FractionNode fraction =
          (nodeFor(item) as RowNode).children.single as FractionNode;

      expect((fraction.numerator as NumeralNode).digits, '3');
      expect((fraction.denominator as NumeralNode).digits, '4');
    });

    test('the token order is preserved', () {
      const Item item = Item(
        id: 'i',
        prompt: <PromptToken>[
          PromptToken.text('9'),
          PromptToken.operator('−'),
          PromptToken.text('4'),
          PromptToken.operator('='),
        ],
        expected: '5',
        ladderStep: 1,
      );

      final RowNode row = nodeFor(item) as RowNode;

      expect((row.children[0] as NumeralNode).digits, '9');
      expect((row.children[1] as OperatorNode).glyph, '−');
      expect((row.children[2] as NumeralNode).digits, '4');
      expect((row.children[3] as OperatorNode).glyph, '=');
    });

    test('an operator defaults to the face D7 gives it', () {
      const Item item = Item(
        id: 'i',
        prompt: <PromptToken>[
          PromptToken.operator('+'),
          PromptToken.operator('='),
        ],
        expected: '1',
        ladderStep: 1,
      );

      final RowNode row = nodeFor(item) as RowNode;

      expect((row.children[0] as OperatorNode).face, MathFace.display);
      expect((row.children[1] as OperatorNode).face, MathFace.textHeavy);
    });

    test('a solidus in a prompt is refused rather than drawn inline', () {
      const Item item = Item(
        id: 'i',
        prompt: <PromptToken>[PromptToken.operator('/')],
        expected: '1',
        ladderStep: 1,
      );

      expect(() => nodeFor(item), throwsA(isA<ArgumentError>()));
    });
  });
}
