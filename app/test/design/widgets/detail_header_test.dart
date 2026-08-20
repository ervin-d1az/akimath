import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/detail_header.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topCenter, child: child),
    ),
  );
}

/// The height the title is **painted** at.
///
/// Not `getSize`, which is the paragraph's own layout height: inside a
/// `FittedBox` the child lays out at its intrinsic size and the box applies a
/// transform, so `getSize` reads 40 for every title and the assertion below was
/// vacuous. `getRect` goes through `localToGlobal` on both corners and so
/// carries the scale.
double titleHeight(WidgetTester tester, String title) =>
    tester.getRect(find.text(title)).height;

void main() {
  group('the header 4.2 to 4.7 share', () {
    testWidgets('draws the title and a way back', (WidgetTester tester) async {
      await pump(tester, DetailHeader(title: 'AJUSTES', onBack: () {}));

      expect(find.text('AJUSTES'), findsOneWidget);
      expect(find.bySemanticsLabel('Volver'), findsOneWidget);
    });

    testWidgets('the back control does what it says', (WidgetTester tester) async {
      int backs = 0;
      await pump(tester, DetailHeader(title: 'CUENTA', onBack: () => backs++));

      await tester.tap(find.bySemanticsLabel('Volver'));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('a finger can land on the back control', (WidgetTester tester) async {
      await pump(tester, DetailHeader(title: 'CUENTA', onBack: () {}));

      final Size hit = tester.getSize(find.bySemanticsLabel('Volver'));
      expect(hit.width, greaterThanOrEqualTo(BrandShape.minTouchTarget));
      expect(hit.height, greaterThanOrEqualTo(BrandShape.minTouchTarget));
    });
  });

  group('the title fits rather than choosing from six sizes', () {
    testWidgets('a short title renders at full size', (WidgetTester tester) async {
      // `AJUSTES` is the design's 40px case and has room.
      await pump(tester, DetailHeader(title: 'AJUSTES', onBack: () {}));

      expect(titleHeight(tester, 'AJUSTES'),
          closeTo(DetailHeader.titleSize, DetailHeader.titleSize * 0.25));
    });

    testWidgets('a long title shrinks instead of wrapping', (WidgetTester tester) async {
      // `SONIDO Y VIBRACIÓN` is the design's 32px case — the longest it draws.
      await pump(tester, DetailHeader(title: 'SONIDO Y VIBRACIÓN', onBack: () {}));

      expect(find.text('SONIDO Y VIBRACIÓN'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final double long = titleHeight(tester, 'SONIDO Y VIBRACIÓN');
      await pump(tester, DetailHeader(title: 'AJUSTES', onBack: () {}));
      final double short = titleHeight(tester, 'AJUSTES');

      expect(long, lessThan(short),
          reason: 'the longer title did not shrink');
    });

    testWidgets('an absurd title still draws one line', (WidgetTester tester) async {
      // Six magic numbers would have none for the seventh screen. This is what
      // fitting buys and enumerating does not.
      await pump(
        tester,
        DetailHeader(
          title: 'DATOS, PRIVACIDAD Y TODO LO DEMÁS QUE QUEPA',
          onBack: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(DetailHeader)).width,
        lessThanOrEqualTo(390),
      );
    });

    testWidgets('it survives a text setting the design never considered',
        (WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topCenter,
              child: DetailHeader(title: 'SONIDO Y VIBRACIÓN', onBack: () {}),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
