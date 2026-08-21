import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/map/ui/skill_map_screen.dart';
import 'package:akimath_app/features/profile/ui/profile_screen.dart';
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
  await tester.pumpWidget(const MaterialApp(home: RootScaffold()));
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
}
