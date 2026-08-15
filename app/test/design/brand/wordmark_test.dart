import 'package:akimath_app/design/brand/wordmark.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reads as one word to a screen reader', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AkiMathWordmark(),
      ),
    );

    expect(find.bySemanticsLabel('AkiMath'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('splits ink and accent at the capital M', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AkiMathWordmark(),
      ),
    );

    final Text text = tester.widget<Text>(find.byType(Text));
    final TextSpan span = text.textSpan! as TextSpan;
    final List<InlineSpan> halves = span.children!;

    expect((halves[0] as TextSpan).text, 'Aki');
    expect((halves[0] as TextSpan).style!.color, BrandColors.ink);
    expect((halves[1] as TextSpan).text, 'Math');
    expect((halves[1] as TextSpan).style!.color, BrandColors.pink);
  });

  testWidgets('turns the accent white on the brand green', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AkiMathWordmark(tone: WordmarkTone.onBrandGreen),
      ),
    );

    final Text text = tester.widget<Text>(find.byType(Text));
    final List<InlineSpan> halves = (text.textSpan! as TextSpan).children!;

    expect(
      (halves[1] as TextSpan).style!.color,
      BrandColors.surface,
      reason: 'Two accent colors never appear at once.',
    );
  });

  test('refuses to render below the legibility floor', () {
    expect(
      () => AkiMathWordmark(
        fontSize: BrandShape.minWordmarkFontSize - 1,
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => AkiMathWordmark(fontSize: BrandShape.minWordmarkFontSize),
      returnsNormally,
    );
  });

  test('is written one way, everywhere', () {
    expect(AkiMathWordmark.plainText, 'AkiMath');
    expect(AkiMathWordmark.plainText, isNot(contains("'")));
    expect(AkiMathWordmark.plainText, isNot(contains(' ')));
  });
}
