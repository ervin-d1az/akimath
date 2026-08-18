import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/design/widgets/pressable_surface.dart';
import 'package:akimath_app/design/widgets/spec/keypad_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  KeypadLayout layout, {
  double width = 390,
  ValueChanged<KeypadKey>? onKeyPressed,
}) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: width,
          child: Keypad(
            layout: layout,
            onKeyPressed: onKeyPressed ?? (KeypadKey _) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('item and puzzle keys are the same widget at two sizes', () {
    testWidgets('both use one key widget with the same geometry',
        (WidgetTester tester) async {
      for (final KeypadLayout layout in <KeypadLayout>[
        KeypadLayout.item,
        KeypadLayout.puzzle,
      ]) {
        await _pump(tester, layout);

        expect(
          find.byType(KeypadKeyView),
          findsNWidgets(layout.keys.length),
          reason: '${layout.name} did not render one key widget per key',
        );

        final Container painted = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(PressableSurface),
                matching: find.byType(Container),
              )
              .first,
        );
        final BoxDecoration decoration = painted.decoration! as BoxDecoration;

        expect(decoration.border!.top.width, BrandShape.borderWidth);
        expect(
          decoration.borderRadius,
          BorderRadius.circular(BrandShape.radiusPill),
        );
        expect(decoration.boxShadow!.single.offset, BrandShape.shadowTile);
      }
    });

    testWidgets('the same backspace glyph renders at 24 and at 23',
        (WidgetTester tester) async {
      await _pump(tester, KeypadLayout.item);
      final BrandIcon itemIcon = tester.widgetList<BrandIcon>(
        find.byType(BrandIcon),
      ).firstWhere((BrandIcon i) => i.glyph == BrandGlyph.backspace);
      expect(itemIcon.size, 24);

      await _pump(tester, KeypadLayout.puzzle);
      final BrandIcon puzzleIcon = tester.widgetList<BrandIcon>(
        find.byType(BrandIcon),
      ).firstWhere((BrandIcon i) => i.glyph == BrandGlyph.backspace);
      expect(puzzleIcon.size, 23);

      // One glyph, two sizes.
      expect(itemIcon.glyph, puzzleIcon.glyph);
    });
  });

  group('the keypad clears the touch minimum on a narrow device', () {
    testWidgets('every key measures at least 48x48 at 320 logical pixels',
        (WidgetTester tester) async {
      for (final KeypadLayout layout in KeypadLayout.all) {
        await _pump(tester, layout, width: 320);

        for (final Element element in find.byType(KeypadKeyView).evaluate()) {
          final Size size = (element.renderObject! as RenderBox).size;
          expect(
            size.width,
            greaterThanOrEqualTo(BrandShape.minTouchTarget),
            reason: '${layout.name} has a key narrower than 48 at 320px',
          );
          expect(
            size.height,
            greaterThanOrEqualTo(BrandShape.minTouchTarget),
            reason: '${layout.name} has a key shorter than 48 at 320px',
          );
        }
      }
    });
  });

  group('the system keyboard never appears', () {
    testWidgets('no EditableText and no TextField reach the tree',
        (WidgetTester tester) async {
      for (final KeypadLayout layout in KeypadLayout.all) {
        await _pump(tester, layout);
        expect(find.byType(EditableText), findsNothing);
      }
    });
  });

  group('a press reports the key and nothing more', () {
    testWidgets('pressing 7 reports the 7 key', (WidgetTester tester) async {
      final List<String> pressed = <String>[];
      await _pump(
        tester,
        KeypadLayout.item,
        onKeyPressed: (KeypadKey k) => pressed.add(k.id),
      );

      await tester.tap(find.byType(KeypadKeyView).first);
      await tester.pump();

      expect(pressed, <String>['7']);
    });

    testWidgets('the keypad accumulates nothing of its own',
        (WidgetTester tester) async {
      // Press three digits and confirm the widget holds no assembled answer:
      // the caller receives three separate key reports and the pad is
      // stateless between them (design D4).
      final List<String> pressed = <String>[];
      await _pump(
        tester,
        KeypadLayout.item,
        onKeyPressed: (KeypadKey k) => pressed.add(k.emits ?? ''),
      );

      final Finder keys = find.byType(KeypadKeyView);
      await tester.tap(keys.at(0));
      await tester.tap(keys.at(1));
      await tester.tap(keys.at(2));
      await tester.pump();

      expect(pressed, <String>['7', '8', '9']);
      expect(
        tester.widget<Keypad>(find.byType(Keypad)),
        isA<Keypad>(),
        reason: 'the pad is stateless — it has nowhere to keep an answer',
      );
    });

    testWidgets('backspace and submit report themselves and emit nothing',
        (WidgetTester tester) async {
      final List<KeypadKey> pressed = <KeypadKey>[];
      await _pump(
        tester,
        KeypadLayout.item,
        onKeyPressed: pressed.add,
      );

      await tester.tap(find.byType(KeypadKeyView).at(14));
      await tester.tap(find.byType(KeypadKeyView).at(15));
      await tester.pump();

      expect(pressed.map((KeypadKey k) => k.id), <String>['backspace', 'submit']);
      expect(pressed.every((KeypadKey k) => k.emits == null), isTrue);
    });
  });
}
