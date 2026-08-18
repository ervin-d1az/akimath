import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/features/shell/policy/banner_visual.dart';
import 'package:akimath_app/features/shell/ui/inline_banner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget banner) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 360, child: banner)),
      ),
    );

BoxDecoration _decorationOf(WidgetTester tester) =>
    tester.widget<Container>(
      find.descendant(
        of: find.byType(InlineBanner),
        matching: find.byType(Container),
      ),
    ).decoration! as BoxDecoration;

void main() {
  group('a banner always draws its glyph', () {
    // The doc comment promises it and `resolveBannerVisual` returns one; until
    // now nothing checked the widget actually painted it. An enum pinned in a
    // policy test is not coverage of the arm that consumes it — the
    // `MathTone.muted` lesson, one file over.
    for (final BannerKind kind in BannerKind.values) {
      testWidgets('${kind.name} renders its glyph', (WidgetTester tester) async {
        await _pump(tester, InlineBanner(kind: kind, message: 'Hola'));

        expect(find.byType(BrandIcon), findsOneWidget);
        expect(
          tester.widget<BrandIcon>(find.byType(BrandIcon)).glyph,
          resolveBannerVisual(kind).glyph,
        );
      });
    }

    testWidgets('the two kinds draw different glyphs',
        (WidgetTester tester) async {
      await _pump(
        tester,
        const InlineBanner(kind: BannerKind.error, message: 'x'),
      );
      final BrandGlyph error =
          tester.widget<BrandIcon>(find.byType(BrandIcon)).glyph;

      await _pump(
        tester,
        const InlineBanner(kind: BannerKind.notice, message: 'x'),
      );
      final BrandGlyph notice =
          tester.widget<BrandIcon>(find.byType(BrandIcon)).glyph;

      expect(error, isNot(notice));
      expect(notice, BrandGlyph.wifiOff);
    });
  });

  group('the hue encodes whose fault it is', () {
    testWidgets('an error is coral and a notice is yellow',
        (WidgetTester tester) async {
      // Both arms of the tone switch, which nothing reached before.
      await _pump(
        tester,
        const InlineBanner(kind: BannerKind.error, message: 'x'),
      );
      expect(_decorationOf(tester).color, BrandColorRole.error.color);

      await _pump(
        tester,
        const InlineBanner(kind: BannerKind.notice, message: 'x'),
      );
      expect(_decorationOf(tester).color, BrandColorRole.highlight.color);
    });
  });

  group('placement is a skin, not a second widget', () {
    testWidgets('each placement resolves its own radius',
        (WidgetTester tester) async {
      // K7's entire content. Both arms of the placement switch.
      await _pump(
        tester,
        const InlineBanner(
          kind: BannerKind.notice,
          message: 'x',
          placement: BannerPlacement.inline,
        ),
      );
      expect(
        _decorationOf(tester).borderRadius,
        BorderRadius.circular(BrandShape.radiusChip),
      );

      await _pump(
        tester,
        const InlineBanner(
          kind: BannerKind.notice,
          message: 'x',
          placement: BannerPlacement.topBand,
        ),
      );
      expect(
        _decorationOf(tester).borderRadius,
        BorderRadius.circular(BrandShape.radiusPanel),
      );
    });

    testWidgets('the two placements differ only in radius',
        (WidgetTester tester) async {
      // If they diverged on anything else they would be two widgets kept in
      // agreement by hand, which is what K7 exists to prevent.
      await _pump(
        tester,
        const InlineBanner(kind: BannerKind.error, message: 'x'),
      );
      final BoxDecoration inline = _decorationOf(tester);

      await _pump(
        tester,
        const InlineBanner(
          kind: BannerKind.error,
          message: 'x',
          placement: BannerPlacement.topBand,
        ),
      );
      final BoxDecoration band = _decorationOf(tester);

      expect(band.color, inline.color);
      expect(band.border, inline.border);
      expect(
        band.boxShadow!.single.offset,
        inline.boxShadow!.single.offset,
      );
      expect(band.borderRadius, isNot(inline.borderRadius));
    });
  });

  group('the action chip is both or neither', () {
    testWidgets('no chip when neither label nor callback is given',
        (WidgetTester tester) async {
      await _pump(
        tester,
        const InlineBanner(kind: BannerKind.notice, message: 'Sin conexión'),
      );
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('no chip when only a label is given',
        (WidgetTester tester) async {
      await _pump(
        tester,
        const InlineBanner(
          kind: BannerKind.notice,
          message: 'Sin conexión',
          actionLabel: 'Reintentar',
        ),
      );
      expect(
        find.text('Reintentar'),
        findsNothing,
        reason: 'a chip with no callback is a button that does nothing',
      );
    });

    testWidgets('a chip appears when both are given, and it fires once',
        (WidgetTester tester) async {
      int taps = 0;
      await _pump(
        tester,
        InlineBanner(
          kind: BannerKind.notice,
          message: 'Sin conexión',
          actionLabel: 'Reintentar',
          onAction: () => taps++,
        ),
      );

      expect(find.text('Reintentar'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('the message is shown', () {
    testWidgets('a long message wraps rather than overflowing',
        (WidgetTester tester) async {
      await _pump(
        tester,
        const InlineBanner(
          kind: BannerKind.notice,
          message: 'Sin conexión. Tus respuestas se guardan y se envían '
              'cuando vuelvas a tener internet.',
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
