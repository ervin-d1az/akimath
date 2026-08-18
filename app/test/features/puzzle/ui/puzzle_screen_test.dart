import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_board_view.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<List<int>> _solution = <List<int>>[
  <int>[1, 2, 3],
  <int>[2, 3, 1],
  <int>[3, 1, 2],
];

KenKenPuzzle _puzzle() => KenKenPuzzle(
      board: const PuzzleBoard(
        size: 3,
        blocked: <Cell>{},
        given: <Cell>{},
        solution: _solution,
      ),
      cages: <Cage>[
        Cage(
          cells: <Cell>[
            for (int row = 0; row < 3; row++)
              for (int col = 0; col < 3; col++) Cell(row: row, col: col),
          ],
          operation: '+',
          target: 18,
        ),
      ],
      tutorialSteps: const <String>['Cada fila lleva 1, 2 y 3.'],
      referenceSheet: const <String>[
        'Ningún número se repite en su fila ni en su columna.',
        'La esquina de la jaula dice el resultado.',
      ],
    );

Future<int> _pump(WidgetTester tester, {VoidCallback? onClose}) async {
  int solved = 0;
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: PuzzleScreen(
        puzzle: _puzzle(),
        onClose: onClose,
        onSolved: () => solved++,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return solved;
}

Future<void> _press(WidgetTester tester, String id) async {
  await tester.tap(find.byWidgetPredicate(
    (Widget w) => w is KeypadKeyView && w.data.id == id,
  ));
  await tester.pump();
}

/// The control carrying an accessible label.
///
/// Matched on the `Semantics` widget rather than through the semantics tree:
/// `bySemanticsLabel` needs a `SemanticsHandle`, and a handle taken in a helper
/// outlives the end-of-test verification that insists it be disposed. This
/// asserts the same thing — the label is on the control — without that dance.
Finder _labelled(String label) => find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.label == label,
    );

/// A value **on the board**, not on the keypad.
///
/// The pad's own faces are 1 to 9, so a bare `find.text('2')` matches a key and
/// says nothing about the grid. Every board assertion is scoped, and the first
/// draft of this file was green for the wrong reason before that.
Finder _onBoard(String value) => find.descendant(
      of: find.byType(PuzzleBoardView),
      matching: find.text(value),
    );

/// Taps the cell at [row], [col] — the board lays them out in reading order.
Future<void> _tapCell(WidgetTester tester, int row, int col) async {
  // Scoped to the board for the same reason `_onBoard` is: the header buttons
  // and every keypad key are gesture detectors too, so an unscoped index taps
  // something else entirely and the test passes having exercised nothing.
  await tester.tap(
    find
        .descendant(
          of: find.byType(PuzzleBoardView),
          matching: find.byType(GestureDetector),
        )
        .at(row * 3 + col),
  );
  await tester.pump();
}

void main() {
  group('the screen composes the board and the pad it was built for', () {
    testWidgets('both are there', (WidgetTester tester) async {
      await _pump(tester);
      expect(find.byType(PuzzleBoardView), findsOneWidget);
      // The 5×2 puzzle pad: nine digits and a backspace, and no submit — a
      // board announces itself finished rather than being submitted.
      expect(find.byType(KeypadKeyView), findsNWidgets(10));
      expect(
        find.byWidgetPredicate(
            (Widget w) => w is KeypadKeyView && w.data.id == 'submit'),
        findsNothing,
      );
    });
  });

  group('playing it', () {
    testWidgets('a digit lands in the selected cell',
        (WidgetTester tester) async {
      await _pump(tester);
      await _tapCell(tester, 0, 0);
      await _press(tester, '1');

      expect(_onBoard('1'), findsOneWidget);
    });

    testWidgets('backspace clears it', (WidgetTester tester) async {
      await _pump(tester);
      await _tapCell(tester, 1, 1);
      await _press(tester, '2');
      await _press(tester, 'backspace');

      expect(_onBoard('2'), findsNothing);
    });

    testWidgets('a digit with nothing selected does nothing',
        (WidgetTester tester) async {
      await _pump(tester);
      await _press(tester, '1');
      expect(_onBoard('1'), findsNothing);
    });
  });

  group('finishing', () {
    testWidgets('solving the last cell reports it once',
        (WidgetTester tester) async {
      int solved = 0;
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PuzzleScreen(puzzle: _puzzle(), onSolved: () => solved++),
        ),
      );
      await tester.pumpAndSettle();

      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
          await _tapCell(tester, row, col);
          await _press(tester, '${_solution[row][col]}');
        }
      }

      expect(solved, 1);

      // And typing again does not report a second time — a callback firing on
      // every keystroke after completion would push a verdict per digit.
      await _tapCell(tester, 0, 0);
      await _press(tester, '1');
      expect(solved, 1);
    });

    testWidgets('a full but wrong board reports nothing',
        (WidgetTester tester) async {
      int solved = 0;
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PuzzleScreen(puzzle: _puzzle(), onSolved: () => solved++),
        ),
      );
      await tester.pumpAndSettle();

      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
          await _tapCell(tester, row, col);
          // Every cell a 1: full, and wrong everywhere it matters.
          await _press(tester, '1');
        }
      }

      expect(solved, 0);
    });
  });

  group('the way out and the rules', () {
    testWidgets('there is exactly one way out', (WidgetTester tester) async {
      bool closed = false;
      await _pump(tester, onClose: () => closed = true);

      await tester.tap(_labelled('Salir'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });

    testWidgets('the rules come from the pack and are shown on demand',
        (WidgetTester tester) async {
      // Three lines in front of a board is a wall between a player and the
      // thing they came for.
      await _pump(tester);
      expect(find.textContaining('se repite'), findsNothing);

      await tester.tap(_labelled('Cómo se juega'));
      await tester.pumpAndSettle();
      expect(find.textContaining('se repite'), findsOneWidget);
    });
  });
}
