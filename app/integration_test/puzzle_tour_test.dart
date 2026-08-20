import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/onboarding/ui/welcome_screen.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_board_view.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_screen.dart';
import 'package:akimath_app/features/puzzle/ui/word_search_screen.dart';
import 'package:akimath_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opens every board format on a real device, and solves the one with a keypad.
///
/// The keypad it types on has existed since F0 and was wired to nothing until
/// the puzzles landed, so this was the first evidence it works at all.
///
/// **And now every format, because "five are reachable" was only ever a widget
/// test.** `home_route_test.dart` walks the shipped pack in the fake harness;
/// this walks it on a device, which is where a board that renders but cannot be
/// laid out at 390 px, or a card whose label wraps out of reach, actually
/// shows up. `f6-killer` and `f6-word-search` both left their Tier 2 open
/// waiting for exactly this.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the day\'s puzzle can be opened and solved',
      (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 6));

    if (find.byType(WelcomeScreen).evaluate().isNotEmpty) {
      await tester.tap(find.text('Resolver uno'));
      await tester.pumpAndSettle();
      for (final String id in <String>['1', '3', 'submit']) {
        await tester.tap(find.byWidgetPredicate(
            (Widget w) => w is KeypadKeyView && w.data.id == id));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }
    for (int i = 0; i < 20 && find.byType(HomeScreen).evaluate().isEmpty; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    }

    // `ROMPECABEZAS` is the section heading; the cards are under it, one per
    // puzzle the pack carries. Tapping the heading was tapping a `Text`.
    expect(find.text('ROMPECABEZAS'), findsOneWidget);
    await tester.ensureVisible(find.text('KenKen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KenKen'));
    for (int i = 0; i < 20 && find.byType(PuzzleScreen).evaluate().isEmpty; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    }
    expect(find.byType(PuzzleScreen), findsOneWidget);

    // **Read off the live board, not written down here.** `puzzlesOfDay` rotates
    // through seven boards per format, so a hardcoded solution is a test that
    // passes one day in seven — which, in a suite nothing ran, would have looked
    // like flakiness rather than a wrong assumption.
    final PuzzleBoard board =
        tester.widget<PuzzleScreen>(find.byType(PuzzleScreen)).puzzle.board;
    final List<List<int>> solution = board.solution;
    final int size = board.size;
    final Finder cells = find.descendant(
      of: find.byType(PuzzleBoardView),
      matching: find.byType(GestureDetector),
    );

    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        // A cell the board already supplies is not typeable, and tapping one
        // then pressing a digit is how a filled board ends up rejected.
        if (board.given.contains(Cell(row: row, col: col)) ||
            board.blocked.contains(Cell(row: row, col: col))) {
          continue;
        }
        await tester.tap(cells.at(row * size + col));
        await tester.pump();
        await tester.tap(find.byWidgetPredicate((Widget w) =>
            w is KeypadKeyView && w.data.id == '${solution[row][col]}'));
        await tester.pump();
      }
    }
    await tester.pumpAndSettle();

    // Solving ends the session and shows `¡Lo armaste!` — a screen that did
    // not exist when this test was written, which is why it expected the home
    // directly. Nothing ran it, so nothing said so.
    expect(find.byType(PuzzleScreen), findsNothing,
        reason: 'a solved board should end the session');
    expect(find.text('¡Lo armaste!'), findsOneWidget);

    await tester.tap(find.text('Seguir'));
    for (int i = 0; i < 20 && find.byType(HomeScreen).evaluate().isEmpty; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    }
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('every format the pack carries opens from the home',
      (WidgetTester tester) async {
    await _reachHome(tester);

    // **Read off the live home, not written down here.** The pack decides what
    // it carries; a list in this file would be a second declaration of the
    // shipped content and would pass while the pack lost a format.
    final List<String> names = tester
        .widget<HomeScreen>(find.byType(HomeScreen))
        .puzzles
        .map((PuzzleOption option) => option.label)
        .toList();
    // PROC-10: a pack that lost its puzzles would make the loop below vacuous
    // and the whole case would pass by walking nothing.
    expect(names, isNotEmpty);
    expect(names, hasLength(5), reason: 'the shipped pack carries five formats');

    for (final String name in names) {
      await tester.ensureVisible(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      for (int i = 0; i < 20 && !_onABoard(); i++) {
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
      }
      expect(_onABoard(), isTrue, reason: '$name did not open');

      // **Out through `Salir`, not `pageBack`.** A puzzle is pushed
      // full-screen with no navigation affordance — that is the design — so
      // there is no `CupertinoNavigationBarBackButton` for the harness to
      // press. Both screens carry the same labelled control, which is the one
      // route a player actually has.
      // Matched on the `Semantics` widget rather than through
      // `bySemanticsLabel`, which reads the compiled semantics tree and needs
      // it switched on. The widget is there either way, and it is the thing
      // the label is attached to.
      await tester.tap(find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.label == 'Salir',
        description: 'the way out of a full-screen board',
      ));
      for (int i = 0; i < 20 && find.byType(HomeScreen).evaluate().isEmpty; i++) {
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
      }
      expect(find.byType(HomeScreen), findsOneWidget, reason: 'stuck after $name');
    }
  });
}

/// Whether a board of either kind is on screen.
///
/// Two screens, because the sopa de letras has no keypad and therefore no
/// `PuzzleScreen`: its drag is resolved by `letterAt` rather than by a detector
/// per cell, which is why it did not fit the shared one.
bool _onABoard() =>
    find.byType(PuzzleScreen).evaluate().isNotEmpty ||
    find.byType(WordSearchScreen).evaluate().isNotEmpty;

/// The first run, then the home. Shared by both cases in this file.
Future<void> _reachHome(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 6));

  if (find.byType(WelcomeScreen).evaluate().isNotEmpty) {
    await tester.tap(find.text('Resolver uno'));
    await tester.pumpAndSettle();
    for (final String id in <String>['1', '3', 'submit']) {
      await tester.tap(find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == id));
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
}
