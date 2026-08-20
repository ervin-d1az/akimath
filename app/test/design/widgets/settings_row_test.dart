import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/settings_row.dart';
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

void main() {
  group('a disclosure row', () {
    testWidgets('says where it goes and goes there', (WidgetTester tester) async {
      int opened = 0;
      await pump(tester, SettingsRow(label: 'Cuenta', onOpen: () => opened++));

      expect(find.text('Cuenta'), findsOneWidget);
      await tester.tap(find.text('Cuenta'));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('carries a chevron by default', (WidgetTester tester) async {
      await pump(tester, SettingsRow(label: 'Cuenta', onOpen: () {}));

      expect(
        tester.widget<BrandIcon>(find.byType(BrandIcon)).glyph,
        BrandGlyph.forward,
      );
    });

    testWidgets('a value sits before the chevron', (WidgetTester tester) async {
      // `4.2`'s `Notificaciones` row shows `19:30` beside its chevron.
      await pump(
        tester,
        SettingsRow(label: 'Recordatorio', value: '19:30', onOpen: () {}),
      );

      expect(find.text('19:30'), findsOneWidget);
      expect(find.byType(BrandIcon), findsOneWidget);
      expect(
        tester.getCenter(find.text('19:30')).dx,
        lessThan(tester.getCenter(find.byType(BrandIcon)).dx),
      );
    });

    testWidgets('a row that opens nothing draws no chevron', (WidgetTester tester) async {
      // `4.3`'s `Cerrar sesión` acts in place; a chevron would promise a screen
      // that never arrives.
      await pump(
        tester,
        SettingsRow(label: 'Cerrar sesión', onOpen: () {}, showChevron: false),
      );

      expect(find.byType(BrandIcon), findsNothing);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('a finger can land on the whole row', (WidgetTester tester) async {
      await pump(tester, SettingsRow(label: 'Cuenta', onOpen: () {}));

      final Size hit = tester.getSize(find.byType(SettingsRow));
      expect(hit.height, greaterThanOrEqualTo(BrandShape.minTouchTarget));
    });

    testWidgets('a long label does not overflow at 1.3', (WidgetTester tester) async {
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
              child: SettingsRow(
                label: 'Cómo se leen los retos',
                value: '19:30',
                onOpen: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
