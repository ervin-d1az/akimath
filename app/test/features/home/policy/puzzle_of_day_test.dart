import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/features/home/policy/puzzle_menu.dart';
import 'package:akimath_app/features/home/policy/puzzle_of_day.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _steps = <String>['x'];

PuzzleBoard _board(int corner) => PuzzleBoard.caged(
      size: 2,
      blocked: <Cell>{},
      given: <Cell>{},
      solution: <List<int>>[
        <int>[corner, 3 - corner],
        <int>[3 - corner, corner],
      ],
    );

/// A KenKen whose top-left value names it, so a test can say which board it got.
KenKenPuzzle _kenken(int corner) => KenKenPuzzle(
      board: _board(corner),
      cages: const <Cage>[
        Cage(cells: <Cell>[Cell(row: 0, col: 0), Cell(row: 0, col: 1)], target: 3, operation: '+'),
        Cage(cells: <Cell>[Cell(row: 1, col: 0), Cell(row: 1, col: 1)], target: 3, operation: '+'),
      ],
      tutorialSteps: _steps,
      referenceSheet: _steps,
    );

KillerPuzzle _killer() => KillerPuzzle(
      board: _board(1),
      cages: const <Cage>[
        Cage(cells: <Cell>[Cell(row: 0, col: 0), Cell(row: 0, col: 1)], target: 3),
        Cage(cells: <Cell>[Cell(row: 1, col: 0), Cell(row: 1, col: 1)], target: 3),
      ],
      tutorialSteps: _steps,
      referenceSheet: _steps,
    );

const WordSearchPuzzle _wordSearch = WordSearchPuzzle(
  grid: <String>['SUM', 'ABC', 'DEF'],
  words: <String>['SUM'],
  tutorialSteps: _steps,
  referenceSheet: _steps,
);

/// Which board came back, by the marker in its top-left cell.
int _corner(Puzzle puzzle) => (puzzle as BoardPuzzle).board.solution[0][0];

void main() {
  group('a format is offered once, however many boards it has', () {
    test('three KenKens make one card', () {
      // Two cards with the same name are two cards a player cannot choose
      // between — the reason `puzzleMenu` insists the names be distinct.
      final List<Puzzle> pack = <Puzzle>[_kenken(1), _kenken(2), _kenken(1)];

      final List<Puzzle> offered = puzzlesOfDay(pack, today: DateTime(2026, 8, 18));

      expect(offered, hasLength(1));
      expect(puzzleMenu(offered), <String>['KenKen']);
    });

    test('the kinds come in pack order, by first appearance', () {
      final List<Puzzle> pack = <Puzzle>[
        _wordSearch,
        _kenken(1),
        _killer(),
        _kenken(2),
      ];

      expect(
        puzzleMenu(puzzlesOfDay(pack, today: DateTime(2026, 8, 18))),
        <String>['Sopa de letras', 'KenKen', 'Suma con jaulas'],
      );
    });

    test('an empty pack offers nothing', () {
      expect(puzzlesOfDay(const <Puzzle>[], today: DateTime(2026, 8, 18)), isEmpty);
    });
  });

  group('a day is the unit', () {
    final List<Puzzle> pack = <Puzzle>[_kenken(1), _kenken(2)];

    test('the same day is the same board', () {
      // Leaving a puzzle and coming back has to continue it, not replace it.
      final Puzzle morning = puzzlesOfDay(pack, today: DateTime(2026, 8, 18, 7)).single;
      final Puzzle evening = puzzlesOfDay(pack, today: DateTime(2026, 8, 18, 22, 59)).single;

      expect(_corner(morning), _corner(evening));
    });

    test('consecutive days rotate through every board of a kind', () {
      // A rotation that repeated would leave content in the pack a player
      // never reaches.
      final Set<int> seen = <int>{
        for (int day = 18; day <= 20; day += 1)
          _corner(puzzlesOfDay(pack, today: DateTime(2026, 8, day)).single),
      };

      expect(seen, <int>{1, 2});
    });

    test('the next day is the next board, not a jump', () {
      final int first = _corner(puzzlesOfDay(pack, today: DateTime(2026, 8, 18)).single);
      final int second = _corner(puzzlesOfDay(pack, today: DateTime(2026, 8, 19)).single);

      expect(second, isNot(first));
    });

    test('one board is that board every day', () {
      final List<Puzzle> single = <Puzzle>[_kenken(1)];

      for (int day = 1; day <= 5; day += 1) {
        expect(_corner(puzzlesOfDay(single, today: DateTime(2026, 8, day)).single), 1);
      }
    });
  });

  group('a calendar day, not twenty-four hours', () {
    test('a daylight-saving transition still advances by one', () {
      // 8 March 2026 is a spring-forward Sunday in much of the United States,
      // so the local day is 23 hours. `Duration`-based arithmetic loses it and
      // hands the player the same board twice — the bug `streak_policy_test`
      // already guards against under `TZ=America/Tijuana`.
      expect(dayNumber(DateTime(2026, 3, 9)) - dayNumber(DateTime(2026, 3, 8)), 1);
      expect(dayNumber(DateTime(2026, 11, 2)) - dayNumber(DateTime(2026, 11, 1)), 1);
    });

    test('every hour of a day is the same day', () {
      final Set<int> numbers = <int>{
        for (int hour = 0; hour < 24; hour += 1) dayNumber(DateTime(2026, 3, 8, hour)),
      };

      expect(numbers, hasLength(1));
    });

    test('it advances by one across a month and a year boundary', () {
      expect(dayNumber(DateTime(2026, 9, 1)) - dayNumber(DateTime(2026, 8, 31)), 1);
      expect(dayNumber(DateTime(2027, 1, 1)) - dayNumber(DateTime(2026, 12, 31)), 1);
    });

    test('a day before the epoch is still a day apart', () {
      // Nothing stops a device's clock being wrong, and a negative day number
      // must not make the rotation index negative.
      expect(dayNumber(DateTime(1999, 1, 2)) - dayNumber(DateTime(1999, 1, 1)), 1);
    });

    test('a clock set before the epoch still picks a board', () {
      // Dart's `%` is Euclidean, so a negative day number is still a valid
      // index — in C or JavaScript it would not be, and this is the assertion
      // that keeps `boards[day % n]` honest rather than lucky.
      //
      // **A week of them, not one day.** A single pre-epoch date lands on a
      // parity: with two boards, half of them give a remainder of zero and pass
      // for a signed modulo too.
      final List<Puzzle> pack = <Puzzle>[_kenken(1), _kenken(2)];

      for (int day = 1; day <= 7; day += 1) {
        expect(
          () => puzzlesOfDay(pack, today: DateTime(1999, 1, day)),
          returnsNormally,
          reason: '1999-01-0$day',
        );
        expect(puzzlesOfDay(pack, today: DateTime(1999, 1, day)), hasLength(1));
      }
    });
  });
}
