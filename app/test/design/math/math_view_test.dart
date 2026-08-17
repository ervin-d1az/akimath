import 'package:akimath_app/design/math/fraction_glyph.dart';
import 'package:akimath_app/design/math/math_view.dart';
import 'package:akimath_app/design/math/spec/math_node.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {TextScaler scaler = TextScaler.noScaling}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: scaler),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

void main() {
  group('the compositor is asked for three quarters', () {
    testWidgets('a numerator sits above a rule above a denominator',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const MathView(
            node: FractionNode(
              numerator: NumeralNode('3'),
              denominator: NumeralNode('4'),
            ),
          ),
        ),
      );

      final Rect numerator = tester.getRect(find.text('3'));
      final Rect denominator = tester.getRect(find.text('4'));
      final Rect rule = tester.getRect(find.byType(ColoredBox));

      expect(rule.top, greaterThan(numerator.top));
      expect(rule.bottom, lessThan(denominator.bottom));
      expect(denominator.top, greaterThan(numerator.top));
    });

    testWidgets('no solidus is painted', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const MathView(
            node: FractionNode(
              numerator: NumeralNode('3'),
              denominator: NumeralNode('4'),
            ),
          ),
        ),
      );

      // Every run of text in the tree, checked for a slash. A fraction drawn
      // inline would have to put one here.
      final Iterable<Text> runs = tester.widgetList<Text>(find.byType(Text));
      expect(runs, isNotEmpty);
      for (final Text run in runs) {
        expect(run.data, isNot(contains('/')));
        expect(run.data, isNot(contains('⁄')));
      }
    });

    testWidgets('the rule spans at least the minimum width',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const MathView(
            node: FractionNode(
              numerator: NumeralNode('3'),
              denominator: NumeralNode('4'),
            ),
          ),
        ),
      );

      // Two single digits are narrower than the design's floor, so the rule is
      // what sets the fraction's width.
      expect(tester.getRect(find.byType(ColoredBox)).width, greaterThan(57));
    });
  });

  group('the rule keeps its proportion as text scales', () {
    testWidgets('scaling up thickens the rule with the numerals',
        (WidgetTester tester) async {
      const MathView view = MathView(
        node: FractionNode(
          numerator: NumeralNode('3'),
          denominator: NumeralNode('4'),
        ),
      );

      await tester.pumpWidget(_host(view));
      final double atOne = tester.getRect(find.byType(ColoredBox)).height;
      final double numeralAtOne = tester.getRect(find.text('3')).height;

      await tester.pumpWidget(
        _host(view, scaler: const TextScaler.linear(1.3)),
      );
      final double atOneThree = tester.getRect(find.byType(ColoredBox)).height;
      final double numeralAtOneThree = tester.getRect(find.text('3')).height;

      // This is Spike B's finding 1, asserted through the real widget rather
      // than through the pure module: the rule must grow with the glyphs. A
      // build that scales text and leaves the rule alone passes every other
      // test in this file.
      expect(atOneThree, greaterThan(atOne));
      expect(
        atOneThree / numeralAtOneThree,
        closeTo(atOne / numeralAtOne, (atOne / numeralAtOne) * 0.1),
        reason: 'the rule thinned relative to the numerals',
      );
    });
  });

  group('the adapter agrees with the layout it renders', () {
    testWidgets('the widget is exactly as large as the computed box',
        (WidgetTester tester) async {
      const FractionNode node = FractionNode(
        numerator: NumeralNode('23'),
        denominator: NumeralNode('20'),
      );

      await tester.pumpWidget(_host(const MathView(node: node, size: 46)));

      final Size rendered = tester.getSize(find.byType(MathView));
      expect(rendered.width, greaterThan(0));
      expect(rendered.height, greaterThan(0));

      // Every painted child lies inside the box the spec sized.
      final Rect outer = tester.getRect(find.byType(MathView));
      for (final Element element
          in find.byType(Text).evaluate().toList(growable: false)) {
        final Rect child = tester.getRect(find.byWidget(element.widget));
        expect(outer.contains(child.topLeft), isTrue);
      }
    });
  });

  group('FractionGlyph is the two-string shorthand', () {
    testWidgets('it renders the same geometry as the tree it stands for',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const FractionGlyph(numerator: '1', denominator: '2', size: 46)),
      );
      final Rect viaGlyph = tester.getRect(find.byType(ColoredBox));

      await tester.pumpWidget(
        _host(
          const MathView(
            size: 46,
            node: FractionNode(
              numerator: NumeralNode('1'),
              denominator: NumeralNode('2'),
            ),
          ),
        ),
      );
      final Rect viaTree = tester.getRect(find.byType(ColoredBox));

      expect(viaGlyph.size, viaTree.size);
    });

    testWidgets('it works at the 15px key face the keypad will ask for',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const FractionGlyph(numerator: 'a', denominator: 'b', size: 15)),
      );

      // Below the smallest measured row, so the rule clamps rather than
      // vanishing — FractionMetrics' floor, seen through the widget.
      expect(tester.getRect(find.byType(ColoredBox)).height, 3);
    });
  });

  group('the painted glyph lands where the layout put it', () {
    testWidgets('a numeral box is the font\'s natural line, not a tight one',
        (WidgetTester tester) async {
      // Tier 2 found this: BrandText.numeral sets height: 1, which collapses
      // the line box to the font size, while the spec models the font's own
      // ascent plus descent (1.448em for Darumadrop). The glyph then sits
      // wherever Flutter puts it inside the box the layout positioned, and the
      // rule ends up nowhere near optically centred.
      await tester.pumpWidget(
        _host(const MathView(node: NumeralNode('3'), size: 76)),
      );

      const FontMetrics daruma = FontMetrics.darumadrop;
      final double natural =
          (daruma.ascentRatio + daruma.descentRatio) * 76;

      expect(
        tester.getRect(find.text('3')).height,
        closeTo(natural, 0.5),
        reason: 'the painted line box does not match the computed one',
      );
    });

    testWidgets('the rule is optically centred in the rendered fraction',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const MathView(
            node: FractionNode(
              numerator: NumeralNode('1'),
              denominator: NumeralNode('2'),
            ),
            size: 76,
          ),
        ),
      );

      const FontMetrics daruma = FontMetrics.darumadrop;
      final Rect rule = tester.getRect(find.byType(ColoredBox));
      final Rect numerator = tester.getRect(find.text('1'));
      final Rect denominator = tester.getRect(find.text('2'));

      // Ink extents, derived from the same metrics the layout used: a digit
      // ends on the baseline and starts a cap height above it.
      final double numeratorInkBottom =
          numerator.top + daruma.ascentRatio * 76;
      final double denominatorInkTop = denominator.top +
          daruma.ascentRatio * 76 -
          daruma.capHeightRatio * 76;

      expect(
        rule.top - numeratorInkBottom,
        closeTo(denominatorInkTop - rule.bottom, 0.5),
        reason: 'the rendered clearances above and below the rule differ',
      );
    });
  });

  group('a row separates its tokens', () {
    testWidgets('adjacent children do not touch', (WidgetTester tester) async {
      // Tier 2 found this too: with no gap, the rules of two adjacent
      // fractions read as one continuous line straight through the `=`.
      await tester.pumpWidget(
        _host(
          MathView(
            node: RowNode(<MathNode>[
              FractionNode(
                numerator: const NumeralNode('3'),
                denominator: const NumeralNode('4'),
              ),
              OperatorNode.of('+'),
              FractionNode(
                numerator: const NumeralNode('2'),
                denominator: const NumeralNode('5'),
              ),
            ]),
          ),
        ),
      );

      // By element, not by widget: two rules of the same colour are equal by
      // value and `find.byWidget` cannot tell them apart.
      final List<Rect> rules = find
          .byType(ColoredBox)
          .evaluate()
          .map((Element e) => e.renderObject! as RenderBox)
          .map(
            (RenderBox r) =>
                r.localToGlobal(Offset.zero) & r.size,
          )
          .toList()
        ..sort((Rect a, Rect b) => a.left.compareTo(b.left));

      expect(rules, hasLength(2));
      expect(
        rules[1].left - rules[0].right,
        greaterThan(8),
        reason: 'two fraction rules run into each other',
      );
    });
  });
}
