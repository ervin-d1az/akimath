import 'package:akimath_app/features/shell/ui/app_shell.dart';
import 'package:akimath_app/features/shell/ui/tab_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A session takes the whole screen, bar and all.
///
/// Declared rule 1: *"La barra inferior desaparece en sesión. Reto, acierto,
/// error, calibración y puzzle son pantalla completa: no hay a dónde irse hasta
/// cerrar o salir a propósito."*
///
/// **This is here because giving each tab its own navigator broke it.** Before
/// `TabStack`, `Navigator.of(context)` inside a root found the app's navigator
/// and a session covered everything. Afterwards it finds the *tab's* first, so
/// the round was pushed under the bar — a player mid-item could tap away, and
/// the screen lost 106 pixels it was laid out for, which is how a 24-pixel
/// overflow reached a device.
void main() {
  testWidgets('a session covers the bar, unlike a settings push',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TabStack(
            child: Builder(
              builder: (BuildContext inner) => Column(
                children: <Widget>[
                  TextButton(
                    onPressed: () => pushSession<void>(
                      inner,
                      (BuildContext _) => const Text('sesión'),
                    ),
                    child: const Text('jugar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(inner).push(
                      MaterialPageRoute<void>(builder: (_) => const Text('ajustes')),
                    ),
                    child: const Text('ajustar'),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const SizedBox(height: 72, child: Text('barra')),
        ),
      ),
    );

    await tester.tap(find.text('jugar'));
    await tester.pumpAndSettle();
    expect(find.text('sesión'), findsOneWidget);
    expect(find.text('barra'), findsNothing,
        reason: 'the bar has to disappear in a session');

    // **Not `pageBack()`.** A session has no back button — that is the rule,
    // not an omission — so leaving it is the screen's own close control, or in
    // a harness the navigator that owns it.
    expect(find.byType(BackButton), findsNothing);
    final NavigatorState root =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    root.pop();
    await tester.pumpAndSettle();

    // And the other kind of push is unchanged: a settings screen sits above a
    // home, so the bar stays.
    await tester.tap(find.text('ajustar'));
    await tester.pumpAndSettle();
    expect(find.text('ajustes'), findsOneWidget);
    expect(find.text('barra'), findsOneWidget);
  });
}
