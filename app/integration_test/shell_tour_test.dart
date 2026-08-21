import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/map/ui/skill_map_screen.dart';
import 'package:akimath_app/features/shell/ui/nav_bar.dart';
import 'package:akimath_app/features/onboarding/ui/welcome_screen.dart';
import 'package:akimath_app/features/preferences/ui/legend_screen.dart';
import 'package:akimath_app/features/preferences/ui/settings_list_screen.dart';
import 'package:akimath_app/features/profile/ui/profile_screen.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Walks the shell on a real device: splash, first run, home, all three roots,
/// and the settings stack above one of them.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a player can reach every root and the stack above one', (WidgetTester tester) async {
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

    // The bar exists because a second root does.
    expect(find.text('Inicio'), findsOneWidget);
    // **`Mapa` is the third**, and it is on the bar rather than merely built:
    // `05 MAPA` and `2.7 Detalle de nodo` were merged fully tested with nothing
    // that opened either.
    expect(find.text('Mapa'), findsOneWidget);
    // **`Perfil`, not `Ajustes`.** Declared rule 1 names the bar's homes as
    // *inicio, mapa, progreso y perfil*; the third root was labelled after a
    // settings screen, which that rule does not name.
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Ajustes'), findsNothing);
    // And no `Avance`: it absorbed into the profile, which is where the design
    // draws what it held.
    expect(find.text('Avance'), findsNothing);

    // **And each root carries a mark, not just a word.** A mark that stopped
    // rendering would leave the labels in place and look like a spacing change.
    final Finder marks =
        find.descendant(of: find.byType(NavBar), matching: find.byType(BrandIcon));
    expect(marks, findsNWidgets(3), reason: 'one mark per root');

    // The map opens from the bar, on a real device, at the real text setting.
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillMapScreen), findsOneWidget);
    expect(find.byType(NavBar), findsOneWidget, reason: 'a root keeps the bar');

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    // The gear opens the stack, and the bar is still under it — the group badge
    // over 4.1–4.7 says so: *"Aquí sí va la barra inferior."*
    await tester.tap(find.bySemanticsLabel('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsListScreen), findsOneWidget);
    expect(find.byType(NavBar), findsOneWidget, reason: 'the bar left with the push');

    await tester.tap(find.text('Cómo se leen los retos'));
    await tester.pumpAndSettle();
    expect(find.byType(LegendScreen), findsOneWidget);
    // The legend's own words, which `fix-verdict-copy` changed from `Acierto`
    // and `Se torció`. This suite kept the old pair for weeks because nothing
    // ran it — `flutter test` does not reach `integration_test/`.
    expect(find.text('¡Bien hecho!'), findsOneWidget);
    expect(find.text('Casi'), findsOneWidget);

    // Back out of the stack, twice, and the profile is still there.
    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    // **The figures are here, not on a root of their own.** `Avance` was
    // invented because the shell needed a second root; no document draws a
    // progress screen, and every line it held is a line `4.1` puts under the
    // identity.
    //
    // The wide card reads `RATING` rather than `DÍAS` while the demo figures
    // are on: the days practised are what that slot falls back to when there
    // is no rating to show. `RACHA` and `RETOS` are the device's own and are
    // true either way.
    expect(find.text('RACHA'), findsOneWidget);
    expect(find.text('RETOS'), findsOneWidget);
    // No account on a fresh install, so there is no history section at all —
    // a `HISTORIAL` nothing can ever fill is a promise the product cannot keep
    // while nothing syncs.
    expect(find.text('HISTORIAL'), findsNothing);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget, reason: 'the home lost its state');
  });
}
