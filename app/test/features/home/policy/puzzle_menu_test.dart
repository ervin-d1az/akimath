import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/content/model/puzzle_reader.dart';
import 'package:akimath_app/features/home/policy/puzzle_menu.dart';
import 'package:flutter_test/flutter_test.dart';

PuzzleBoard _board() => PuzzleBoard.caged(
      size: 2,
      blocked: <Cell>{},
      given: <Cell>{},
      solution: const <List<int>>[
        <int>[1, 2],
        <int>[2, 1],
      ],
    );

const List<Cage> _cages = <Cage>[
  Cage(cells: <Cell>[Cell(row: 0, col: 0), Cell(row: 0, col: 1)], target: 3, operation: '+'),
  Cage(cells: <Cell>[Cell(row: 1, col: 0), Cell(row: 1, col: 1)], target: 3, operation: '+'),
];

const List<String> _steps = <String>['x'];

/// One of every kind, in the frozen order.
List<Puzzle> _all() => <Puzzle>[
      KenKenPuzzle(
        board: _board(),
        cages: _cages,
        tutorialSteps: _steps,
        referenceSheet: _steps,
      ),
      KillerPuzzle(
        board: _board(),
        cages: _cages,
        tutorialSteps: _steps,
        referenceSheet: _steps,
      ),
      MagicSquarePuzzle(
        board: _board(),
        rowTargets: const <int>[3, 3],
        columnTargets: const <int>[3, 3],
        tutorialSteps: _steps,
        referenceSheet: _steps,
      ),
      KakuroPuzzle(
        board: PuzzleBoard(
          size: 2,
          blocked: <Cell>{},
          given: <Cell>{},
          solution: const <List<int>>[
            <int>[1, 2],
            <int>[2, 1],
          ],
          highestValue: 9,
        ),
        runs: const <Run>[
          Run(cells: <Cell>[Cell(row: 0, col: 0), Cell(row: 0, col: 1)], sum: 3),
        ],
        tutorialSteps: _steps,
        referenceSheet: _steps,
      ),
      const WordSearchPuzzle(
        grid: <String>['SUM', 'ABC', 'DEF'],
        words: <String>['SUM'],
        tutorialSteps: _steps,
        referenceSheet: _steps,
      ),
    ];

void main() {
  group('every kind has a name a player would recognise', () {
    test('one name per frozen kind, all different', () {
      // Five cards reading "Rompecabezas" would be five cards a player cannot
      // choose between. The names have to be distinct or the menu is decoration.
      final List<String> names = _all().map(puzzleName).toList();

      expect(names, hasLength(frozenPuzzleKinds.length));
      expect(names.toSet(), hasLength(frozenPuzzleKinds.length));
      expect(names, everyElement(isNotEmpty));
    });

    test('the names are the ones the cards show', () {
      expect(
        _all().map(puzzleName).toList(),
        <String>['KenKen', 'Suma con jaulas', 'Cuadro mágico', 'Kakuro', 'Sopa de letras'],
      );
    });
  });

  group('the menu keeps the pack in order', () {
    test('it names every puzzle the pack carries, in pack order', () {
      expect(
        puzzleMenu(_all()),
        <String>['KenKen', 'Suma con jaulas', 'Cuadro mágico', 'Kakuro', 'Sopa de letras'],
      );
    });

    test('the order is the pack\'s, not the frozen list\'s', () {
      // Reversed, so a menu that sorted by kind — or rebuilt the frozen order
      // from `frozenPuzzleKinds` — would come back the other way round.
      expect(
        puzzleMenu(_all().reversed.toList()),
        <String>['Sopa de letras', 'Kakuro', 'Cuadro mágico', 'Suma con jaulas', 'KenKen'],
      );
    });

    test('a pack with two of a kind names both', () {
      // Nothing stops a pack carrying two word searches, and dropping the
      // second because its name repeats would hide a puzzle the player paid
      // for. The menu is a list, not a set.
      final List<Puzzle> pack = <Puzzle>[_all().last, _all().last];

      expect(puzzleMenu(pack), <String>['Sopa de letras', 'Sopa de letras']);
    });

    test('an empty pack has an empty menu', () {
      expect(puzzleMenu(const <Puzzle>[]), isEmpty);
    });
  });
}
