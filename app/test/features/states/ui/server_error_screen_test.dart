import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/features/states/ui/server_error_screen.dart';
import 'package:akimath_app/features/states/ui/state_chip.dart';
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
  group('4.10 Error de servidor', () {
    testWidgets('takes the blame and says where the progress is', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        ServerErrorScreen(note: 'error 503 · 18:42', onRetry: () {}),
      );

      expect(find.text('NO SOMOS TÚ,'), findsOneWidget);
      expect(find.text('SOMOS NOSOTROS'), findsOneWidget);
      expect(
        find.text(
          'El servidor no contestó. Tu progreso está a salvo en este teléfono.',
        ),
        findsOneWidget,
      );
    });

    // *"sin Aki: no le toca"*, annotated on the design itself, and the declared
    // rules say it twice: *"No mientras se resuelve, no en errores de cuenta ni
    // de servidor."* An apology from the dog reads as the dog being at fault.
    testWidgets('Aki is not here, because this is not hers', (
      WidgetTester tester,
    ) async {
      await pump(tester, ServerErrorScreen(note: null, onRetry: () {}));

      expect(find.byType(Aki), findsNothing);
    });

    testWidgets('shows the note when there is one', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        ServerErrorScreen(note: 'error 503 · 18:42', onRetry: () {}),
      );

      expect(find.text('error 503 · 18:42'), findsOneWidget);
      expect(find.byType(StateChip), findsOneWidget);
    });

    testWidgets('draws no chip when there is nothing true to put in it', (
      WidgetTester tester,
    ) async {
      await pump(tester, ServerErrorScreen(note: null, onRetry: () {}));

      expect(find.byType(StateChip), findsNothing);
    });

    testWidgets('retrying is the primary way out', (WidgetTester tester) async {
      int retried = 0;
      await pump(
        tester,
        ServerErrorScreen(note: null, onRetry: () => retried++),
      );

      await tester.tap(find.text('Intentar de nuevo'));
      await tester.pump();

      expect(retried, 1);
    });

    testWidgets('the second way out is offered when the caller has one', (
      WidgetTester tester,
    ) async {
      int played = 0;
      await pump(
        tester,
        ServerErrorScreen(
          note: null,
          onRetry: () {},
          onSolveOffline: () => played++,
        ),
      );

      await tester.tap(find.text('Resolver sin conexión'));
      await tester.pump();

      expect(played, 1);
    });

    // A caller with no series to start — the profile — offers one way out
    // rather than a button that does nothing (DR-P2).
    testWidgets('and is absent when it does not', (WidgetTester tester) async {
      await pump(tester, ServerErrorScreen(note: null, onRetry: () {}));

      expect(find.text('Resolver sin conexión'), findsNothing);
      expect(find.text('Intentar de nuevo'), findsOneWidget);
    });
  });
}
