import 'package:akimath_app/design/painting/dashed_border_painter.dart';
import 'package:akimath_app/design/painting/spec/cage_outline.dart';
import 'package:akimath_app/design/painting/spec/dash_spec.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/candy_surface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    );

void main() {
  group('the focused answer slot', () {
    testWidgets('is dashed pink at 3px, radius 12, with no solid border',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          CandySurface(
            borderDash: DashSpec.locked,
            borderColor: BrandColorRole.focus.color,
            borderWidth: BrandShape.borderWidth,
            borderRadius: BrandShape.radiusSlot,
            shadowOffset: Offset.zero,
            child: const SizedBox(width: 96, height: 52),
          ),
        ),
      );

      final Container container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CandySurface),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;

      // The solid border is gone — not drawn underneath the dash.
      expect(
        decoration.border,
        isNull,
        reason: 'a dashed surface must not also paint a solid border',
      );

      final DashedBorderPainter painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(CandySurface),
              matching: find.byType(CustomPaint),
            ),
          )
          .foregroundPainter! as DashedBorderPainter;

      expect(painter.color, BrandColorRole.focus.color);
      expect(painter.strokeWidth, BrandShape.borderWidth);
      expect(painter.radius, BrandShape.radiusSlot);
      expect(painter.dash, DashSpec.locked);
    });

    testWidgets('an undashed surface keeps its solid border and paints no dash',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const CandySurface(child: SizedBox(width: 96, height: 52)),
        ),
      );

      final Container container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CandySurface),
          matching: find.byType(Container),
        ),
      );
      expect((container.decoration! as BoxDecoration).border, isNotNull);
      expect(
        find.descendant(
          of: find.byType(CandySurface),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });

  group('a cage outline is inset inside the hairline it sits on', () {
    // Cages ship in F6. The numbers are recorded here because they are a
    // property of the outline geometry and they are in the digests today —
    // so F6 consumes a tested figure instead of re-deriving it from a mock.

    test('the KenKen cage is 2.5px pink, rx 10, inset 5', () {
      expect(CageOutline.kenKen.strokeWidth, BrandShape.borderWidthSmallSurface);
      expect(CageOutline.kenKen.radius, 10);
      expect(CageOutline.kenKen.inset, 5);
      expect(CageOutline.kenKen.dash, DashSpec.kenKenCage);
    });

    test('the Killer cage is rx 9, inset 6, with a round cap', () {
      expect(CageOutline.killer.radius, 9);
      expect(CageOutline.killer.inset, 6);
      expect(CageOutline.killer.dash.cap, DashCap.round);
    });

    test('neither overlaps the 1.5px hairline beneath it', () {
      // The hairline is centred on the cell edge, so it reaches half its width
      // inward. A cage whose stroke reaches back that far would sit on it.
      const double hairlineReach = CageOutline.cellHairline / 2;

      for (final CageOutline cage in <CageOutline>[
        CageOutline.kenKen,
        CageOutline.killer,
      ]) {
        expect(
          cage.inset - cage.strokeWidth / 2,
          greaterThan(hairlineReach),
          reason: 'the cage outline overlaps the hairline beneath it',
        );
      }
    });
  });
}
