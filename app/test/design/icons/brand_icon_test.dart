import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    );

void main() {
  group('a glyph set between two numbers must not read as arithmetic', () {
    /// Characters a reader would take as a relation between the numbers either
    /// side of them. A stand-in is free to be approximate; it is not free to be
    /// a different, false statement.
    const List<String> readsAsComparison = <String>['›', '‹', '>', '<', '=', '≥', '≤'];

    testWidgets('the mapping glyph is not one of them',
        (WidgetTester tester) async {
      // The defect: `hidden_operation_view` and `analogy_view` drew
      // `BrandGlyph.forward`, whose stand-in is `›`. Between two numerals
      // `2 › 4` is indistinguishable from `2 > 4` — a false statement, printed
      // by a maths app, in the one place a player is being asked to work out a
      // rule from the numbers in front of them.
      await tester.pumpWidget(const _Harness(BrandGlyph.mapsTo));

      for (final String forbidden in readsAsComparison) {
        expect(find.text(forbidden), findsNothing,
            reason: 'the mapping glyph renders "$forbidden"');
      }
    });

    testWidgets('it is an arrow', (WidgetTester tester) async {
      await tester.pumpWidget(const _Harness(BrandGlyph.mapsTo));
      expect(find.text('→'), findsOneWidget);
    });

    testWidgets('the card chevron keeps its chevron',
        (WidgetTester tester) async {
      // `forward` is still correct where it means "this card opens something",
      // which is the home's puzzle list. Only its use between numerals was
      // wrong.
      await tester.pumpWidget(const _Harness(BrandGlyph.forward));
      expect(find.text('›'), findsOneWidget);
    });
  });


  group('every named glyph renders something', () {
    // The artwork is not transcribed yet — see the note on BrandIcon. What this
    // guarantees meanwhile is that no call site gets a silent blank, which is
    // how a missing icon reaches a screenshot unnoticed.
    for (final BrandGlyph glyph in BrandGlyph.values) {
      testWidgets('${glyph.name} is not blank', (WidgetTester tester) async {
        await tester.pumpWidget(_host(BrandIcon(glyph)));

        final Text text = tester.widget<Text>(find.byType(Text));
        expect(text.data, isNotNull);
        expect(text.data, isNotEmpty);
      });
    }
  });

  group('the glyph is sized and coloured by its caller', () {
    testWidgets('it occupies exactly the size it was asked for',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(const BrandIcon(BrandGlyph.check, size: 32)));
      expect(tester.getSize(find.byType(BrandIcon)), const Size(32, 32));
    });

    testWidgets('one glyph at two sizes is one glyph', (WidgetTester tester) async {
      // The backspace appears at 24 on the item keypad and 23 on the puzzle
      // keypad. That is one glyph rendered twice, never two named glyphs —
      // which is how a 21-glyph set becomes a 40-glyph set that disagrees with
      // itself.
      await tester.pumpWidget(
        _host(const BrandIcon(BrandGlyph.backspace, size: 24)),
      );
      final String? at24 = tester.widget<Text>(find.byType(Text)).data;

      await tester.pumpWidget(
        _host(const BrandIcon(BrandGlyph.backspace, size: 23)),
      );
      final String? at23 = tester.widget<Text>(find.byType(Text)).data;

      expect(at24, at23);
      expect(tester.getSize(find.byType(BrandIcon)), const Size(23, 23));
    });

    testWidgets('it holds no palette of its own', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          BrandIcon(BrandGlyph.alert, color: BrandColorRole.error.color),
        ),
      );

      expect(
        tester.widget<Text>(find.byType(Text)).style!.color,
        BrandColorRole.error.color,
      );
    });

    testWidgets('it does not scale with the text scaler',
        (WidgetTester tester) async {
      // An icon inside a fixed 48px tile that grew with the accessibility text
      // setting would overflow the tile. Its size is the caller's business.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _host(const BrandIcon(BrandGlyph.submit, size: 24)),
        ),
      );

      expect(tester.getSize(find.byType(BrandIcon)), const Size(24, 24));
    });
  });
}

/// The smallest tree that draws one glyph.
class _Harness extends StatelessWidget {
  const _Harness(this.glyph);

  final BrandGlyph glyph;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: BrandIcon(glyph),
      );
}
