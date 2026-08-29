import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/design/puzzle/spec/cage_outline.dart';
import 'package:akimath_app/features/puzzle/policy/cage_appearance.dart';
import 'package:flutter_test/flutter_test.dart';

const List<List<int>> _solution = <List<int>>[
  <int>[1, 2, 3],
  <int>[2, 3, 1],
  <int>[3, 1, 2],
];

const PuzzleBoard _caged = PuzzleBoard.caged(
  size: 3,
  blocked: <Cell>{},
  given: <Cell>{},
  solution: _solution,
);

const List<Cage> _oneCage = <Cage>[
  Cage(cells: <Cell>[Cell(row: 0, col: 0), Cell(row: 0, col: 1)], target: 5),
];

const List<String> _steps = <String>['Cada fila lleva 1, 2 y 3.'];
const List<String> _sheet = <String>['La esquina dice el resultado.'];

/// One puzzle of every frozen format, so the sweeps below are total rather
/// than a list somebody remembered to extend (PROC-10).
final List<Puzzle> _everyFormat = <Puzzle>[
  KenKenPuzzle(
    board: _caged,
    cages: const <Cage>[
      Cage(
        cells: <Cell>[Cell(row: 0, col: 0), Cell(row: 0, col: 1)],
        operation: '+',
        target: 3,
      ),
    ],
    tutorialSteps: _steps,
    referenceSheet: _sheet,
  ),
  KillerPuzzle(
    board: _caged,
    cages: _oneCage,
    tutorialSteps: _steps,
    referenceSheet: _sheet,
  ),
  MagicSquarePuzzle(
    board: PuzzleBoard(
      size: 3,
      blocked: const <Cell>{},
      given: const <Cell>{},
      solution: _solution,
      highestValue: 9,
    ),
    rowTargets: const <int>[6, 6, 6],
    columnTargets: const <int>[6, 6, 6],
    tutorialSteps: _steps,
    referenceSheet: _sheet,
  ),
  KakuroPuzzle(
    board: PuzzleBoard(
      size: 3,
      blocked: <Cell>{const Cell(row: 0, col: 0)},
      given: const <Cell>{},
      solution: _solution,
      highestValue: 9,
    ),
    runs: const <Run>[
      Run(
        cells: <Cell>[Cell(row: 0, col: 1), Cell(row: 0, col: 2)],
        sum: 5,
      ),
    ],
    tutorialSteps: _steps,
    referenceSheet: _sheet,
  ),
  const WordSearchPuzzle(
    grid: <String>['SUM', 'ARE', 'COS'],
    words: <String>['SUMA'],
    tutorialSteps: _steps,
    referenceSheet: _sheet,
  ),
];

void main() {
  group('a caged format names the outline it is drawn in', () {
    test('KenKen draws the KenKen dash', () {
      expect(cagePlanFor(_everyFormat[0]).outline, CageOutline.kenKen);
    });

    test('Killer draws the Killer dash, not KenKen\'s', () {
      // The defect, stated where it is now decided. `PuzzleScreen` used to read
      // the cages off any `CagedPuzzle` and the board widget named
      // `DashSpec.kenKenCage` itself, so these two were the same drawing.
      final CageOutline? killer = cagePlanFor(_everyFormat[1]).outline;

      expect(killer, CageOutline.killer);
      expect(killer, isNot(CageOutline.kenKen));
    });
  });

  group('cages and their outline travel together', () {
    test('every frozen format pairs them, or has neither', () {
      // The invariant a `const` constructor could not assert: `isEmpty` is not
      // a constant expression, so the guard lives with the one function that
      // produces the pair.
      expect(_everyFormat, hasLength(5));

      for (final Puzzle puzzle in _everyFormat) {
        final CagePlan plan = cagePlanFor(puzzle);
        expect(
          plan.cages.isEmpty,
          plan.outline == null,
          reason: '${puzzle.runtimeType} pairs ${plan.cages.length} cages with '
              '${plan.outline}',
        );
      }
    });

    test('the three formats with no cage draw no outline', () {
      for (final Puzzle puzzle in _everyFormat.skip(2)) {
        expect(cagePlanFor(puzzle).outline, isNull);
        expect(cagePlanFor(puzzle).cages, isEmpty);
      }
    });

    test('a caged format hands back the cages it carries', () {
      expect(cagePlanFor(_everyFormat[1]).cages, _oneCage);
    });
  });
}
