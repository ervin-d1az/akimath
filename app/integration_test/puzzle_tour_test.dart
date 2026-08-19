import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/onboarding/ui/welcome_screen.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_board_view.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_screen.dart';
import 'package:akimath_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opens the day's board on a real device and solves it.
///
/// The keypad it types on has existed since F0 and was wired to nothing until
/// now, so this is the first evidence it works at all.
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
}
