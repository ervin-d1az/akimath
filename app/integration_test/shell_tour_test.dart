import 'package:akimath_app/design/brand/brand_drawing_painter.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/shell/ui/nav_bar.dart';
import 'package:akimath_app/features/onboarding/ui/welcome_screen.dart';
import 'package:akimath_app/features/preferences/ui/preferences_screen.dart';
import 'package:akimath_app/features/progress/ui/progress_screen.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Walks the shell on a real device: splash, first run, home, both tabs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a player can reach both roots', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 6));

    if (find.byType(WelcomeScreen).evaluate().isNotEmpty) {
      await tester.tap(find.text('Resolver uno'));
      await tester.pumpAndSettle();
      for (final String id in <String>['1', '3', 'submit']) {
        await tester.tap(find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == id,
        ));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }

    for (int i = 0; i < 20 && find.byType(HomeScreen).evaluate().isEmpty; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    }
    expect(find.byType(HomeScreen), findsOneWidget, reason: 'never reached the home');

    // The bar exists because a second root does, and it grew when a third did.
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Avance'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);

    // **And each root carries a mark, not just a word.** The two glyphs are
    // hand-drawn (`NavGlyphSpec`) and painted rather than laid out, so nothing
    // in the widget tree names them — a mark that stopped rendering would leave
    // the labels in place and look like a spacing change. Counting the painters
    // inside the bar is what notices.
    final Finder marks = find.descendant(
      of: find.byType(NavBar),
      matching: find.byWidgetPredicate(
        (Widget w) => w is CustomPaint && w.painter is BrandDrawingPainter,
      ),
    );
    expect(marks, findsNWidgets(3), reason: 'one mark per root');

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.byType(PreferencesScreen), findsOneWidget);
    // The legend's own words, which `fix-verdict-copy` changed from `Acierto`
    // and `Se torció`. This suite kept the old pair for weeks because nothing
    // ran it — `flutter test` does not reach `integration_test/`.
    expect(find.text('¡Bien hecho!'), findsOneWidget);
    expect(find.text('Casi'), findsOneWidget);

    // `Avance` is where the two figures live now — they moved off Ajustes when
    // it got its own root, because what a player has done is not a setting.
    await tester.tap(find.text('Avance'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressScreen), findsOneWidget);
    expect(find.text('DÍAS'), findsOneWidget);
    expect(find.text('RACHA'), findsOneWidget);
    // No account on a fresh install, so the history is an invitation.
    expect(find.textContaining('Crea una cuenta'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget, reason: 'the home lost its state');
  });
}
