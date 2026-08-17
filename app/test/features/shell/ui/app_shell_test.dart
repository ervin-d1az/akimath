import 'package:akimath_app/features/shell/policy/banner_visual.dart';
import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
import 'package:akimath_app/features/shell/ui/app_shell.dart';
import 'package:akimath_app/features/shell/ui/inline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
}

void main() {
  group('the app routes without a navigation bar until a second root exists', () {
    testWidgets('one root draws no bar', (WidgetTester tester) async {
      bool built = false;
      await _pump(
        tester,
        AppShell(
          navBar: (List<AppTab> tabs) {
            built = true;
            return const SizedBox.shrink();
          },
          child: const Text('home'),
        ),
      );

      expect(built, isFalse, reason: 'the bar builder was called with one root');
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('two roots draw one', (WidgetTester tester) async {
      List<AppTab>? given;
      await _pump(
        tester,
        AppShell(
          roots: const <AppTab>{AppTab.home, AppTab.skills},
          navBar: (List<AppTab> tabs) {
            given = tabs;
            return const SizedBox(height: 72, child: Text('bar'));
          },
          child: const Text('home'),
        ),
      );

      // The rule is consumed here, not merely tested in isolation: the shell
      // asks visibleTabs and builds what it is given.
      expect(given, <AppTab>[AppTab.home, AppTab.skills]);
      expect(find.text('bar'), findsOneWidget);
    });

    testWidgets('the app as it ships today has no bar',
        (WidgetTester tester) async {
      await _pump(tester, const AppShell(child: Text('home')));
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(visibleTabs(rootsPresentToday), isEmpty);
    });
  });

  group('a full-screen session hides the app frame', () {
    testWidgets('a pushed session carries no navigation',
        (WidgetTester tester) async {
      await _pump(
        tester,
        Builder(
          builder: (BuildContext context) => AppShell(
            roots: const <AppTab>{AppTab.home, AppTab.skills},
            navBar: (List<AppTab> tabs) =>
                const SizedBox(height: 72, child: Text('bar')),
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                fullScreenSession<void>(
                  (BuildContext context) => const Text('la serie'),
                ),
              ),
              child: const Text('Empezar la serie'),
            ),
          ),
        ),
      );

      expect(find.text('bar'), findsOneWidget);

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();

      // Declared rule 1: the session takes the whole screen. The bar below is
      // still mounted in the route underneath, so the assertion is that it is
      // not *visible*, not that it is gone from the tree.
      expect(find.text('la serie'), findsOneWidget);
      expect(find.text('bar'), findsNothing);
    });
  });

  group('the banner sits above the content', () {
    testWidgets('a banner sits above the content it warns about',
        (WidgetTester tester) async {
      // Named for what it checks. It used to say "renders with its glyph" and
      // check no glyph at all, so a grep for glyph coverage returned a false
      // positive — the glyph is `inline_banner_test.dart`'s job.
      await _pump(
        tester,
        const AppShell(
          banner: InlineBanner(
            kind: BannerKind.notice,
            message: 'Sin conexión',
          ),
          child: Text('home'),
        ),
      );

      expect(find.byType(InlineBanner), findsOneWidget);
      expect(find.text('Sin conexión'), findsOneWidget);

      final Rect banner = tester.getRect(find.byType(InlineBanner));
      final Rect content = tester.getRect(find.text('home'));
      expect(banner.top, lessThan(content.top));
    });

    testWidgets('no banner leaves no gap', (WidgetTester tester) async {
      await _pump(tester, const AppShell(child: Text('home')));
      expect(find.byType(InlineBanner), findsNothing);
    });
  });
}
