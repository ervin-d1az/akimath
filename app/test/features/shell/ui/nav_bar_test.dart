import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
import 'package:akimath_app/design/widgets/candy_surface.dart';
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
    testWidgets('the selected tab carries a chip the other does not',
        (WidgetTester tester) async {
      // BRD-1. Ink against muted is a hue difference and would say nothing to
      // a reader with deuteranopia; the chip is present or absent.
      await _pump(tester, current: AppTab.home);

      expect(_chips(tester).evaluate(), hasLength(1), reason: 'exactly one tab is current');
    });

    testWidgets('the chip moves with the selection',
        (WidgetTester tester) async {
      await _pump(tester, current: AppTab.profile);

      // A mark that never moved would satisfy the count above forever.
      final double chip = tester.getCenter(_chips(tester)).dx;

      expect(chip, greaterThan(tester.getCenter(find.text('Inicio')).dx));
      expect(chip, closeTo(tester.getCenter(find.text('Ajustes')).dx, 1));
    });

    testWidgets('the chip is the design\'s green, and bordered',
        (WidgetTester tester) async {
      // `pantallas-base.md` draws the active destination as a green chip with
      // a 3 px border — a shape the rest of the app already speaks, where the
      // dot it replaced was invented because the icons were not ready.
      await _pump(tester, current: AppTab.home);
      final CandySurface chip = tester.widget<CandySurface>(_chips(tester));

      expect(chip.background, BrandColors.green);
      expect(chip.borderWidth, BrandShape.borderWidth);
    });
  });

  group('the bar is a card, not a strip', () {
    testWidgets('it floats, with the app\'s own shadow',
        (WidgetTester tester) async {
      // It used to be full-bleed with a hairline on top, which is the one
      // surface treatment the rest of the app never uses.
      await _pump(tester);
      final CandySurface card = tester.widget<CandySurface>(
        find.descendant(of: find.byType(NavBar), matching: find.byType(CandySurface)).first,
      );

      expect(card.shadowOffset, BrandShape.shadowButton);
      expect(card.borderRadius, BrandShape.radiusCardMedium);
    });

    testWidgets('it is inset from all three edges', (WidgetTester tester) async {
      await _pump(tester);
      final Rect bar = tester.getRect(find.byType(NavBar));
      final Rect card = tester.getRect(
        find.descendant(of: find.byType(NavBar), matching: find.byType(CandySurface)).first,
      );

      expect(card.left, greaterThan(bar.left));
      expect(card.right, lessThan(bar.right));
      expect(card.bottom, lessThan(bar.bottom));
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

/// The chips a bar is currently drawing — a selected tab's surface, and nothing
/// else, since the bar's own card is found by `.first` before them.
Finder _chips(WidgetTester tester) => find.descendant(
      of: find.byType(NavBar),
      matching: find.byWidgetPredicate(
        (Widget w) => w is CandySurface && w.background == BrandColors.green,
      ),
    );
