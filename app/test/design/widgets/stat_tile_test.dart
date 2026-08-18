import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/stat_tile.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

BoxDecoration _decorationOf(WidgetTester tester) =>
    tester.widget<Container>(find.byType(Container).first).decoration!
        as BoxDecoration;

void main() {
  group('the three tile clusters', () {
    // Asserted through the named variants the app uses, not through numbers
    // this test builds — the f0-dashed-border lesson.
    test('each variant carries its own radius, value size and shadow', () {
      expect(StatTileVariant.raised.radius, 20);
      expect(StatTileVariant.raised.valueSize, 26);
      expect(StatTileVariant.raised.shadow, BrandShape.shadowTile);

      expect(StatTileVariant.compact.radius, 18);
      expect(StatTileVariant.compact.valueSize, 24);
      expect(StatTileVariant.compact.shadow, BrandShape.shadowTile);

      expect(StatTileVariant.flat.radius, 16);
      expect(StatTileVariant.flat.valueSize, 22);
      expect(StatTileVariant.flat.shadow, isNull);
    });

    testWidgets('flat draws no shadow and the other two do',
        (WidgetTester tester) async {
      for (final StatTileVariant variant in StatTileVariant.values) {
        await _pump(
          tester,
          StatTile(
            label: 'TIEMPO',
            value: StatValue('4,2 s', size: variant.valueSize),
            variant: variant,
          ),
        );

        final BoxDecoration decoration = _decorationOf(tester);
        expect(
          decoration.borderRadius,
          BorderRadius.circular(variant.radius),
          reason: '${variant.name} drew the wrong radius',
        );
        expect(
          decoration.boxShadow,
          variant.shadow == null ? isEmpty : isNotEmpty,
          reason: '${variant.name} drew the wrong shadow',
        );
      }
    });
  });

  group('the rating delta is two runs, not one span', () {
    testWidgets('a negative delta sets its sign apart from its digits',
        (WidgetTester tester) async {
      await _pump(tester, StatTile.delta(label: 'RATING', delta: -6));

      // Two runs: a sign in the text face and digits in the display face. One
      // span would put a hyphen next to a numeral and set both the same.
      expect(find.text('−'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('−6'), findsNothing);
    });

    testWidgets('the sign is never a hyphen', (WidgetTester tester) async {
      await _pump(tester, StatTile.delta(label: 'RATING', delta: -6));

      for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(contains('-')));
      }
    });

    testWidgets('a positive delta carries a plus and a zero carries nothing',
        (WidgetTester tester) async {
      await _pump(tester, StatTile.delta(label: 'RATING', delta: 6));
      expect(find.text('+'), findsOneWidget);

      await _pump(tester, StatTile.delta(label: 'RATING', delta: 0));
      expect(find.text('+'), findsNothing);
      expect(find.text('−'), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('a four-figure delta is grouped by EsMxNumber',
        (WidgetTester tester) async {
      await _pump(tester, StatTile.delta(label: 'RATING', delta: -1180));

      // U+202F, not a breaking space — the pill it sits in is sized to content.
      expect(find.text('1 180'), findsOneWidget);
    });
  });
}
