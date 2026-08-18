import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
import 'package:akimath_app/features/shell/ui/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppTab?> _pump(
  WidgetTester tester, {
  AppTab current = AppTab.home,
  List<AppTab>? tabs,
}) async {
  AppTab? chosen;
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        bottomNavigationBar: NavBar(
          tabs: tabs ?? visibleTabs(rootsPresentToday),
          current: current,
          onSelect: (AppTab tab) => chosen = tab,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return chosen;
}

void main() {
  group('the bar draws what the policy hands it', () {
    testWidgets('both roots that exist today', (WidgetTester tester) async {
      await _pump(tester);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
    });

    testWidgets('it names no tab that has no root', (WidgetTester tester) async {
      await _pump(tester);
      expect(find.text('Mapa'), findsNothing);
      expect(find.text('Avance'), findsNothing);
    });
  });

  group('where you are is legible without hue', () {
    testWidgets('the selected tab carries a mark the other does not',
        (WidgetTester tester) async {
      // BRD-1. Ink against muted is a hue difference and would say nothing to
      // a reader with deuteranopia; the dot is present or absent.
      await _pump(tester, current: AppTab.home);

      final Iterable<DecoratedBox> dots = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((DecoratedBox d) =>
              (d.decoration as BoxDecoration).shape == BoxShape.circle);

      expect(dots, hasLength(1), reason: 'exactly one tab is current');
    });

    testWidgets('the mark moves with the selection', (WidgetTester tester) async {
      await _pump(tester, current: AppTab.profile);

      // The dot sits above the label of whichever tab is current, so its
      // horizontal position is the assertion — a mark that never moved would
      // satisfy the count above forever.
      final double dot = tester
          .getCenter(find.byWidgetPredicate((Widget w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle))
          .dx;
      expect(dot, greaterThan(tester.getCenter(find.text('Inicio')).dx));
      expect(dot, closeTo(tester.getCenter(find.text('Ajustes')).dx, 1));
    });
  });

  group('every destination is reachable by thumb', () {
    testWidgets('each tab is at least the minimum touch target',
        (WidgetTester tester) async {
      await _pump(tester);

      for (final String label in <String>['Inicio', 'Ajustes']) {
        final Size size = tester.getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(GestureDetector),
          ).first,
        );
        expect(size.height, greaterThanOrEqualTo(BrandShape.minTouchTarget),
            reason: '$label is only ${size.height} tall');
        expect(size.width, greaterThanOrEqualTo(BrandShape.minTouchTarget));
      }
    });
  });

  group('tapping', () {
    testWidgets('another tab reports it', (WidgetTester tester) async {
      AppTab? chosen;
      await _pump(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: NavBar(
              tabs: visibleTabs(rootsPresentToday),
              current: AppTab.home,
              onSelect: (AppTab tab) => chosen = tab,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      expect(chosen, AppTab.profile);
    });

    testWidgets('the whole cell is tappable, not only the label',
        (WidgetTester tester) async {
      // A tab you have to hit precisely is a tab that feels broken.
      AppTab? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: NavBar(
              tabs: visibleTabs(rootsPresentToday),
              current: AppTab.home,
              onSelect: (AppTab tab) => chosen = tab,
            ),
          ),
        ),
      );
      final Rect cell = tester.getRect(
        find.ancestor(
          of: find.text('Ajustes'),
          matching: find.byType(GestureDetector),
        ).first,
      );
      await tester.tapAt(Offset(cell.right - 4, cell.center.dy));
      await tester.pumpAndSettle();

      expect(chosen, AppTab.profile);
    });
  });
}
