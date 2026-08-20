import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/design/widgets/pressable_surface.dart';
import 'package:akimath_app/design/widgets/spec/keypad_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A key's fill says what pressing it does.
///
/// **The pads were entirely white**, and the design has never drawn them that
/// way: digits are white, the operator strip is `pinkSoft`, backspace is
/// `quiet` and submit is the action green. Four fills, and the only one a
/// reader could infer from the glyph is the backspace.
///
/// It is a *role*, not a colour, in the layout: the spec stays pure and the
/// adapter maps a role onto a token, the same split `Verdict` uses to carry an
/// outline and a glyph and no hue.
Future<void> pumpPad(WidgetTester tester, KeypadLayout layout) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Keypad(layout: layout, onKeyPressed: (KeypadKey _) {}),
      ),
    ),
  );
}

Color fillOf(WidgetTester tester, String id) {
  final Finder key = find.byKey(ValueKey<String>('keypad.$id'));
  expect(key, findsOneWidget, reason: 'no key with id "$id" on the pad');
  return tester
      .widget<PressableSurface>(
        find.descendant(of: key, matching: find.byType(PressableSurface)),
      )
      .background!;
}

void main() {
  group('the item pad', () {
    testWidgets('a digit is white', (WidgetTester tester) async {
      await pumpPad(tester, KeypadLayout.item);

      for (final String digit in <String>['0', '5', '9']) {
        expect(fillOf(tester, digit), BrandColors.surface, reason: digit);
      }
      expect(fillOf(tester, 'decimal'), BrandColors.surface);
    });

    testWidgets('the operator strip is the accent', (WidgetTester tester) async {
      // Pink, and pink is never a state here — it is the accent, which is
      // exactly what an operator key is: not right, not wrong, not the action.
      await pumpPad(tester, KeypadLayout.item);

      for (final String id in <String>['fraction', 'negate', 'square']) {
        expect(fillOf(tester, id), BrandColors.pinkSoft, reason: id);
      }
    });

    testWidgets('backspace is quiet and submit is the action',
        (WidgetTester tester) async {
      await pumpPad(tester, KeypadLayout.item);

      expect(fillOf(tester, 'backspace'), BrandColors.quiet);
      expect(fillOf(tester, 'submit'), BrandColorRole.action.color);
    });

    testWidgets('exactly one key on the pad carries the action green',
        (WidgetTester tester) async {
      // *"Verde relleno es acción. En una pantalla solo un elemento lo lleva."*
      // A second green key would make the rule unreadable on the one surface
      // where a player presses sixteen things in a row.
      await pumpPad(tester, KeypadLayout.item);

      final int green = tester
          .widgetList<PressableSurface>(find.byType(PressableSurface))
          .where((PressableSurface s) => s.background == BrandColorRole.action.color)
          .length;
      expect(green, 1);
    });
  });

  group('the other two pads', () {
    testWidgets('the puzzle pad is digits and one quiet backspace',
        (WidgetTester tester) async {
      await pumpPad(tester, KeypadLayout.puzzle);

      expect(fillOf(tester, '1'), BrandColors.surface);
      expect(fillOf(tester, 'backspace'), BrandColors.quiet);
      // It has no submit key, so nothing on it is green.
      final int green = tester
          .widgetList<PressableSurface>(find.byType(PressableSurface))
          .where((PressableSurface s) => s.background == BrandColorRole.action.color)
          .length;
      expect(green, 0);
    });

    testWidgets('the OTP pad commits in green too', (WidgetTester tester) async {
      await pumpPad(tester, KeypadLayout.otp);

      expect(fillOf(tester, 'enter'), BrandColorRole.action.color);
      expect(fillOf(tester, 'backspace'), BrandColors.quiet);
    });
  });

  group('the roles are declared, not inferred from an id', () {
    test('every key any layout declares has a role', () {
      int counted = 0;
      for (final KeypadLayout layout in KeypadLayout.all) {
        for (final KeypadKey key in layout.keys) {
          expect(KeyRole.values, contains(key.role), reason: key.id);
          counted++;
        }
      }
      // PROC-10: a sweep that could pass over nothing is not a sweep.
      expect(counted, greaterThan(0), reason: 'keys swept → $counted');
    });

    test('a key that types is a digit, and a key that acts is not', () {
      // The one relationship worth pinning: `emits` and `role` are two facts
      // about a key and they must not contradict. A green key that typed a
      // character, or a digit that did nothing, is a layout bug.
      for (final KeypadLayout layout in KeypadLayout.all) {
        for (final KeypadKey key in layout.keys) {
          if (key.role == KeyRole.commit || key.role == KeyRole.erase) {
            expect(key.emits, isNull, reason: '${layout.name}/${key.id}');
          } else {
            expect(key.emits, isNotNull, reason: '${layout.name}/${key.id}');
          }
        }
      }
    });
  });
}
