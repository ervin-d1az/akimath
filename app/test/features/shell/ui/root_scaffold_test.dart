import 'package:akimath_app/features/account/data/session_store.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/map/ui/skill_map_screen.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:akimath_app/features/profile/ui/profile_screen.dart';
import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
import 'package:akimath_app/features/shell/ui/root_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether a player can **reach** each root, driven through the bar.
///
/// **The shell had no widget test at all**, which is how `features/map/`
/// landed fully tested with no tab that opened it: every screen under it was
/// pumped directly, and pumping a screen proves nothing about whether anybody
/// can get to it.
Future<void> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // **Signed out on purpose, rather than by accident.** The shell's default
  // store is `PrefsSessionStore`, which in a widget test throws
  // `MissingPluginException` — and the store's broad catch turns that into *no
  // session*. Every case below would pass either way, which is PROC-11's
  // "a `catch` no test reaches" wearing a shell: whether these screens are
  // reachable without an account is the claim, and it is only a claim if the
  // store is empty by declaration. `session_survives_a_relaunch_test.dart`
  // holds the other half.
  await tester.pumpWidget(MaterialApp(
    home: RootScaffold(sessions: InMemorySessionStore()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the bar opens the map', (WidgetTester tester) async {
    await _pump(tester);

    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'never reached the home');

    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();

    expect(find.byType(SkillMapScreen), findsOneWidget);
  });

  testWidgets('and it still opens the profile', (WidgetTester tester) async {
    await _pump(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('the profile is told when it is the root being looked at',
      (WidgetTester tester) async {
    // **The signal the shell alone can send.** `IndexedStack` keeps every root
    // mounted, so the profile's `initState` runs once per launch — and the day
    // log it reads there is written by the home while the profile is behind.
    // Without this it drew `RACHA 0` on the same screenful of app that had just
    // drawn `RACHA 1`, measured on a device.
    await _pump(tester);

    RootVisibility visibilityOfProfile() => tester
        .widget<ProfileRoute>(
          find.byType(ProfileRoute, skipOffstage: false),
        )
        .visibility;

    expect(visibilityOfProfile(), RootVisibility.behind);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(visibilityOfProfile(), RootVisibility.showing);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(visibilityOfProfile(), RootVisibility.behind,
        reason: 'a root that is behind must be able to come back to the front');
  });
}
