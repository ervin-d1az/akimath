import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/brand_button.dart';
import 'package:akimath_app/design/widgets/pressable_surface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    );

BoxDecoration _decorationOf(WidgetTester tester) {
  final Container container = tester.widget<Container>(
    find.descendant(
      of: find.byType(PressableSurface),
      matching: find.byType(Container),
    ),
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('the primary button', () {
    testWidgets('rests on the button shadow and carries the action colour',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(BrandButton.primary(label: 'Continuar', onPressed: () {})),
      );

      final BoxDecoration decoration = _decorationOf(tester);
      expect(decoration.color, BrandColorRole.action.color);
      expect(decoration.boxShadow!.single.offset, BrandShape.shadowButton);
      expect(decoration.boxShadow!.single.blurRadius, 0);
    });

    testWidgets('fires once', (WidgetTester tester) async {
      int presses = 0;
      await tester.pumpWidget(
        _host(BrandButton.primary(label: 'Continuar', onPressed: () => presses++)),
      );

      await tester.tap(find.byType(BrandButton));
      await tester.pump();
      expect(presses, 1);
    });
  });

  group('the secondary button', () {
    testWidgets('a shadowless surface still reports a press',
        (WidgetTester tester) async {
      int presses = 0;
      await tester.pumpWidget(
        _host(
          BrandButton.secondary(label: 'Cancelar', onPressed: () => presses++),
        ),
      );

      final Offset resting = tester.getTopLeft(
        find.descendant(
          of: find.byType(PressableSurface),
          matching: find.byType(Container),
        ),
      );

      await tester.tap(find.byType(BrandButton));
      await tester.pump();

      expect(presses, 1);
      expect(_decorationOf(tester).boxShadow, isEmpty);
      expect(
        tester.getTopLeft(
          find.descendant(
            of: find.byType(PressableSurface),
            matching: find.byType(Container),
          ),
        ),
        resting,
        reason: 'a shadowless surface does not travel',
      );
    });
  });

  group('a tertiary text action is smaller than its hit box', () {
    testWidgets('Dejar la serie hit-tests at 48 while drawn at its own size',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(BrandButton.text(label: 'Dejar la serie', onPressed: () {})),
      );

      final Size hitBox = tester.getSize(find.byType(BrandButton));
      expect(hitBox.height, greaterThanOrEqualTo(BrandShape.minTouchTarget));

      // BRD-2d fires at F2, not later: this control ships on the first playable
      // screen at roughly 29px drawn. The paint stays where the design put it.
      final Size painted = tester.getSize(
        find.descendant(
          of: find.byType(PressableSurface),
          matching: find.byType(Container),
        ),
      );
      expect(painted.height, lessThan(BrandShape.minTouchTarget));
    });

    testWidgets('it carries no outline and no fill', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(BrandButton.text(label: 'Dejar la serie', onPressed: () {})),
      );

      final BoxDecoration decoration = _decorationOf(tester);
      expect(decoration.boxShadow, isEmpty);
      expect(decoration.border, isNull);
      expect(decoration.color, isNull, reason: 'a text action paints no fill');
    });
  });
}
