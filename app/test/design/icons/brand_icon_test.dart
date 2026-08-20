import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/design/icons/spec/icon_paths.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

void main() {
  group('a glyph is geometry now, not a character', () {
    testWidgets('no glyph renders as text any more', (WidgetTester tester) async {
      // The stand-ins were `▲`, `⚙`, `‹` and the rest — deliberate, visible
      // placeholders for a transcription that could not be reached. It can be
      // now, and a `Text` here would mean one slipped through.
      for (final BrandGlyph glyph in BrandGlyph.values) {
        await pump(tester, BrandIcon(glyph));
        expect(find.byType(Text), findsNothing, reason: glyph.name);
      }
    });

    testWidgets('every glyph paints something', (WidgetTester tester) async {
      for (final BrandGlyph glyph in BrandGlyph.values) {
        await pump(tester, BrandIcon(glyph));
        expect(find.byType(CustomPaint), findsWidgets, reason: glyph.name);
      }
    });
  });

  group('size', () {
    testWidgets('a square glyph occupies a square box', (WidgetTester tester) async {
      await pump(tester, const BrandIcon(BrandGlyph.check, size: 20));

      expect(tester.getSize(find.byType(BrandIcon)), const Size(20, 20));
    });

    testWidgets('size is the height, so the oblong arrow keeps its shape',
        (WidgetTester tester) async {
      // `mapsTo` is 30×24 in the design. Squaring it distorts the arrow or
      // letterboxes it, and it appears between two numbers where either is
      // obvious.
      await pump(tester, const BrandIcon(BrandGlyph.mapsTo, size: 24));

      expect(tester.getSize(find.byType(BrandIcon)), const Size(30, 24));
    });

    testWidgets('the arrow scales without distorting', (WidgetTester tester) async {
      await pump(tester, const BrandIcon(BrandGlyph.mapsTo, size: 12));

      expect(tester.getSize(find.byType(BrandIcon)), const Size(15, 12));
    });
  });

  group('what it holds and what it does not', () {
    testWidgets('the colour comes from the caller', (WidgetTester tester) async {
      // `BrandIcon` holds no palette: colours come from `BrandColors` at the
      // call site, per the no-colour-literal gate.
      await pump(
        tester,
        const BrandIcon(BrandGlyph.flame, color: BrandColors.coral),
      );

      expect(tester.widget<BrandIcon>(find.byType(BrandIcon)).color,
          BrandColors.coral);
    });

    testWidgets('the stroke comes from the glyph, not from the size',
        (WidgetTester tester) async {
      // Two glyphs at one size still differ, because the design assigned the
      // weights per mark.
      expect(
        iconPaths[BrandGlyph.submit]!.strokeWidth,
        isNot(iconPaths[BrandGlyph.backspace]!.strokeWidth),
      );
    });

    testWidgets('a glyph does not scale with the text setting',
        (WidgetTester tester) async {
      // An icon inside a 48px key that grew with `textScaler` would burst it,
      // which is what the stand-in characters did — they were `Text`.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: BrandIcon(BrandGlyph.check, size: 20)),
          ),
        ),
      );

      expect(tester.getSize(find.byType(BrandIcon)), const Size(20, 20));
    });
  });
}
