import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/features/puzzle/policy/puzzle_entry.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_board_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<List<int>> _solution = <List<int>>[
  <int>[1, 2, 3],
  <int>[2, 3, 1],
  <int>[3, 1, 2],
];

PuzzleBoard _board({
  Set<Cell> blocked = const <Cell>{},
  Set<Cell> given = const <Cell>{},
}) =>
    PuzzleBoard(size: 3, blocked: blocked, given: given, solution: _solution);

/// One cage over the whole board, so every cell is covered without the test
/// having to describe five of them.
List<Cage> _oneCage(int size) => <Cage>[
      Cage(
        cells: <Cell>[
          for (int row = 0; row < size; row++)
            for (int col = 0; col < size; col++) Cell(row: row, col: col),
        ],
        operation: '+',
        target: 18,
      ),
    ];

Future<PuzzleEntry> _pump(
  WidgetTester tester, {
  PuzzleEntry? entry,
  List<Cage>? cages,
}) async {
  PuzzleEntry current = entry ?? PuzzleEntry.of(_board());
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 330,
            child: PuzzleBoardView(
              entry: current,
              cages: cages ?? _oneCage(current.board.size),
              onTapCell: (Cell cell) => current = current.select(cell),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return current;
}

void main() {
  group('the board draws its cells', () {
    testWidgets('one per square', (WidgetTester tester) async {
      await _pump(tester);
      expect(find.byType(GestureDetector), findsNWidgets(9));
    });

    testWidgets('a given shows its value and an open cell does not',
        (WidgetTester tester) async {
      await _pump(
        tester,
        entry: PuzzleEntry.of(_board(given: <Cell>{const Cell(row: 0, col: 0)})),
      );

      // The given at (0,0) is a 1. Nothing else is filled.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);
    });
  });

  group('the board never draws the answer', () {
    testWidgets('no open cell shows its solution value',
        (WidgetTester tester) async {
      // The solution rides along so grading works offline. A cell that showed
      // what it hides would give the board away.
      await _pump(tester);

      int checked = 0;
      for (final Cell cell in _board().openCells) {
        checked++;
        expect(
          find.text('${_board().valueAt(cell)}'),
          findsNothing,
          reason: '$cell leaked its solution',
        );
      }
      expect(checked, 9, reason: 'the sweep must visit every open cell');
    });

    testWidgets('a value the player entered is drawn, and only that',
        (WidgetTester tester) async {
      final PuzzleEntry entry = PuzzleEntry.of(_board())
          .select(const Cell(row: 1, col: 1))
          .type(2);
      await _pump(tester, entry: entry);

      // (1,1) solves to 3; the player typed 2, so 2 is what appears.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });
  });

  group('a cage says what it asks, once', () {
    testWidgets('the target appears on one cell only',
        (WidgetTester tester) async {
      await _pump(tester);
      // Nine cells in one cage; the label belongs to its top-left corner.
      expect(find.textContaining('18'), findsOneWidget);
    });

    testWidgets('a single-cell cage shows no operation',
        (WidgetTester tester) async {
      // `3+` on a one-cell cage is nonsense — there is nothing to add it to.
      await _pump(
        tester,
        cages: <Cage>[
          const Cage(cells: <Cell>[Cell(row: 0, col: 0)], operation: '+', target: 1),
          Cage(
            cells: <Cell>[
              for (int row = 0; row < 3; row++)
                for (int col = 0; col < 3; col++)
                  if (!(row == 0 && col == 0)) Cell(row: row, col: col),
            ],
            operation: '+',
            target: 17,
          ),
        ],
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('1+'), findsNothing);
    });

    testWidgets('a killer cage shows its target and no operation',
        (WidgetTester tester) async {
      // A `+` there would be a claim `KillerPayloadSchema` does not make: a
      // killer cage asks for a sum by naming nothing.
      await _pump(
        tester,
        cages: <Cage>[
          Cage(
            cells: <Cell>[
              for (int row = 0; row < 3; row++)
                for (int col = 0; col < 3; col++) Cell(row: row, col: col),
            ],
            target: 18,
          ),
        ],
      );

      expect(find.text('18'), findsOneWidget);
      expect(find.text('18+'), findsNothing);
    });

    testWidgets('two cages label two different cells',
        (WidgetTester tester) async {
      await _pump(
        tester,
        cages: <Cage>[
          Cage(
            cells: <Cell>[
              for (int col = 0; col < 3; col++) Cell(row: 0, col: col),
            ],
            operation: '+',
            target: 6,
          ),
          Cage(
            cells: <Cell>[
              for (int row = 1; row < 3; row++)
                for (int col = 0; col < 3; col++) Cell(row: row, col: col),
            ],
            operation: '×',
            target: 12,
          ),
        ],
      );

      expect(find.textContaining('6+'), findsOneWidget);
      expect(find.textContaining('12×'), findsOneWidget);
    });
  });

  group('only open cells respond', () {
    testWidgets('tapping an open cell selects it', (WidgetTester tester) async {
      PuzzleEntry entry = PuzzleEntry.of(_board());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 330,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) =>
                    PuzzleBoardView(
                  entry: entry,
                  cages: _oneCage(3),
                  onTapCell: (Cell cell) =>
                      setState(() => entry = entry.select(cell)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(GestureDetector).at(4));
      await tester.pumpAndSettle();

      expect(entry.selected, isNotNull);
    });

    testWidgets('tapping a given or a blocked cell selects nothing',
        (WidgetTester tester) async {
      PuzzleEntry entry = PuzzleEntry.of(_board(
        given: <Cell>{const Cell(row: 0, col: 0)},
        blocked: <Cell>{const Cell(row: 2, col: 2)},
      ));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 330,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) =>
                    PuzzleBoardView(
                  entry: entry,
                  cages: _oneCage(3),
                  onTapCell: (Cell cell) =>
                      setState(() => entry = entry.select(cell)),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(entry.selected, isNull, reason: 'a given was selected');

      await tester.tap(find.byType(GestureDetector).last);
      await tester.pumpAndSettle();
      expect(entry.selected, isNull, reason: 'a blocked cell was selected');
    });
  });

  group('it fits a phone', () {
    testWidgets('a 6x6 keeps every cell above the touch minimum',
        (WidgetTester tester) async {
      // The tightest layout in the app. 330 px across six cells is 55 each,
      // which clears the 48 px minimum — a 7×7 would not, which is why the
      // format stops at six.
      await _pump(
        tester,
        entry: PuzzleEntry.of(PuzzleBoard(
          size: 6,
          blocked: const <Cell>{},
          given: const <Cell>{},
          solution: <List<int>>[
            for (int row = 0; row < 6; row++)
              <int>[for (int col = 0; col < 6; col++) (row + col) % 6 + 1],
          ],
        )),
        cages: _oneCage(6),
      );

      final Size cell = tester.getSize(find.byType(GestureDetector).first);
      expect(cell.width, greaterThanOrEqualTo(48));
      expect(cell.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  });
}
