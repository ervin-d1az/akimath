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

    expect(find.text('PUZZLE DEL DÍA'), findsOneWidget);
    await tester.tap(find.text('PUZZLE DEL DÍA'));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzleScreen), findsOneWidget);

    // The shipped board is the 3×3 whose solution is 1 2 3 / 2 3 1 / 3 1 2.
    const List<List<int>> solution = <List<int>>[
      <int>[1, 2, 3],
      <int>[2, 3, 1],
      <int>[3, 1, 2],
    ];
    final Finder cells = find.descendant(
      of: find.byType(PuzzleBoardView),
      matching: find.byType(GestureDetector),
    );

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        await tester.tap(cells.at(row * 3 + col));
        await tester.pump();
        await tester.tap(find.byWidgetPredicate((Widget w) =>
            w is KeypadKeyView && w.data.id == '${solution[row][col]}'));
        await tester.pump();
      }
    }
    await tester.pumpAndSettle();

    // Solving pops the session, so the home is what is left.
    expect(find.byType(PuzzleScreen), findsNothing,
        reason: 'a solved board should end the session');
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
