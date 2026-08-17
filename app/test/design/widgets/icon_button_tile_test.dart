import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/icon_button_tile.dart';
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

Size _paintedSize(WidgetTester tester) => tester.getSize(
      find.descendant(
        of: find.byType(PressableSurface),
        matching: find.byType(Container),
      ),
    );

void main() {
  group('the icon tile is one widget, not seven', () {
    testWidgets('the pencil tile toggles its fill and nothing else',
        (WidgetTester tester) async {
      Future<void> pump({required bool toggled}) => tester.pumpWidget(
            _host(
              IconButtonTile(
                toggled: toggled,
                onPressed: () {},
                child: const SizedBox(width: 24, height: 24),
              ),
            ),
          );

      await pump(toggled: false);
      final BoxDecoration off = _decorationOf(tester);
      final Size offSize = _paintedSize(tester);
      final Size offHitBox = tester.getSize(find.byType(IconButtonTile));

      await pump(toggled: true);
      final BoxDecoration on = _decorationOf(tester);
      final Size onSize = _paintedSize(tester);
      final Size onHitBox = tester.getSize(find.byType(IconButtonTile));

      // The fill is the only thing that moves.
      expect(off.color, BrandColors.surface);
      expect(on.color, BrandColorRole.highlight.color);

      expect(onSize, offSize, reason: 'geometry changed with the toggle');
      expect(onHitBox, offHitBox, reason: 'the hit box changed with the toggle');
      expect(on.borderRadius, off.borderRadius);
      expect(
        on.boxShadow!.single.offset,
        off.boxShadow!.single.offset,
        reason: 'the press travel changed with the toggle',
      );
    });

    testWidgets('it is 48 square with the control radius and the pill shadow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          IconButtonTile(
            onPressed: () {},
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      );

      expect(
        _paintedSize(tester),
        const Size(BrandShape.minTouchTarget, BrandShape.minTouchTarget),
      );
      expect(
        _decorationOf(tester).borderRadius,
        BorderRadius.circular(BrandShape.radiusControl),
      );
      expect(_decorationOf(tester).boxShadow!.single.offset, BrandShape.shadowPill);
    });

    testWidgets('it travels into its own shadow like everything else',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          IconButtonTile(
            onPressed: () {},
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      );

      final Offset resting = tester.getTopLeft(
        find.descendant(
          of: find.byType(PressableSurface),
          matching: find.byType(Container),
        ),
      );

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byType(IconButtonTile)));
      await tester.pump();

      final Offset travel = tester.getTopLeft(
            find.descendant(
              of: find.byType(PressableSurface),
              matching: find.byType(Container),
            ),
          ) -
          resting;
      expect(travel, BrandShape.shadowPill);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('it fires once', (WidgetTester tester) async {
      int presses = 0;
      await tester.pumpWidget(
        _host(
          IconButtonTile(
            onPressed: () => presses++,
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      );

      await tester.tap(find.byType(IconButtonTile));
      await tester.pump();
      expect(presses, 1);
    });
  });
}
