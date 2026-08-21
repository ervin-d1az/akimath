import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/features/states/ui/empty_state_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(textDirection: TextDirection.ltr, child: screen),
  );
}

void main() {
  group('4.8 Vacío', () {
    testWidgets('says what is missing and what fills it', (
      WidgetTester tester,
    ) async {
      await pump(tester, EmptyStateScreen(onStart: () {}));

      expect(find.text('TODAVÍA NO HAY'), findsOneWidget);
      expect(find.text('NADA QUE VER'), findsOneWidget);
      expect(
        find.text(
          'Tus habilidades se dibujan solas con los primeros cinco retos.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('draws the two placeholders the design draws', (
      WidgetTester tester,
    ) async {
      await pump(tester, EmptyStateScreen(onStart: () {}));

      expect(find.text('Aquí irá tu primera habilidad'), findsOneWidget);
      expect(find.text('Y aquí la siguiente'), findsOneWidget);
    });

    // The placeholders are `<span>` in the markup, not `<button>`. They stand
    // for a row that does not exist yet, so a press has nowhere to go — and a
    // pressable one would be an affordance that does nothing (DR-P2).
    testWidgets('a placeholder is not pressable', (WidgetTester tester) async {
      await pump(tester, EmptyStateScreen(onStart: () {}));

      expect(
        find.ancestor(
          of: find.text('Aquí irá tu primera habilidad'),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });

    testWidgets('Aki is here — nothing is being solved and nothing failed', (
      WidgetTester tester,
    ) async {
      await pump(tester, EmptyStateScreen(onStart: () {}));

      expect(find.byType(Aki), findsOneWidget);
    });

    testWidgets('the one way out does what it says', (
      WidgetTester tester,
    ) async {
      int started = 0;
      await pump(tester, EmptyStateScreen(onStart: () => started++));

      await tester.tap(find.text('Resolver los primeros 5'));
      await tester.pump();

      expect(started, 1);
    });
  });
}
