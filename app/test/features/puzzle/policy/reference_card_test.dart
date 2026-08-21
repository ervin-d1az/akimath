import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/features/puzzle/policy/reference_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the card shows, decided without a widget.
///
/// The rule text is the pack's and the diagram beside it is ours, so the one
/// thing worth proving is that the two are paired without either being able to
/// invent the other — a line the pack did not carry, or a diagram drawn beside
/// nothing.

const List<List<int>> _threeByThree = <List<int>>[
  <int>[1, 2, 3],
  <int>[2, 3, 1],
  <int>[3, 1, 2],
];

PuzzleBoard _board() => const PuzzleBoard.caged(
      size: 3,
      blocked: <Cell>{},
      given: <Cell>{},
      solution: _threeByThree,
    );

KenKenPuzzle _kenKen(List<String> sheet) => KenKenPuzzle(
      board: _board(),
      cages: const <Cage>[],
      tutorialSteps: const <String>[],
      referenceSheet: sheet,
    );

KakuroPuzzle _kakuro(List<String> sheet) => KakuroPuzzle(
      board: _board(),
      runs: const <Run>[],
      tutorialSteps: const <String>[],
      referenceSheet: sheet,
    );

WordSearchPuzzle _sopa(List<String> sheet) => WordSearchPuzzle(
      grid: const <String>['AB', 'CD'],
      words: const <String>['AB'],
      tutorialSteps: const <String>[],
      referenceSheet: sheet,
    );

void main() {
  group('the rows of a reference card', () {
    test('carry the pack\'s lines, verbatim and in order', () {
      final List<ReferenceRow> rows = referenceRows(
        _kenKen(<String>['primero', 'segundo', 'tercero']),
      );

      expect(
        rows.map((ReferenceRow row) => row.text).toList(),
        <String>['primero', 'segundo', 'tercero'],
      );
    });

    test('pair each line with the diagram its format draws for that place', () {
      final List<ReferenceRow> kenKen = referenceRows(
        _kenKen(<String>['a', 'b', 'c']),
      );
      final List<ReferenceRow> kakuro = referenceRows(
        _kakuro(<String>['a', 'b', 'c']),
      );

      // The vocabulary line is where a format names the thing on its board, so
      // it is the one place two formats must not show the same picture.
      expect(kenKen[1].diagram, isNotNull);
      expect(kakuro[1].diagram, isNotNull);
      expect(kenKen[1].diagram, isNot(kakuro[1].diagram));

      // A cage is a dashed outline, and that is the whole point of drawing one
      // beside the line that first says the word.
      expect(kenKen[1].diagram!.cage, isNotEmpty);
      expect(kakuro[1].diagram!.cage, isEmpty);
    });

    test('give a line the pack added no diagram rather than borrowing one', () {
      // The sheet is the pack's and this code does not get to decide how long
      // it is. A fourth line is text with nothing beside it.
      final List<ReferenceRow> rows = referenceRows(
        _kenKen(<String>['a', 'b', 'c', 'd']),
      );

      expect(rows, hasLength(4));
      expect(rows.last.diagram, isNull);
    });

    test('draw no diagram the pack left no line for', () {
      final List<ReferenceRow> rows = referenceRows(_kenKen(<String>['solo']));

      expect(rows, hasLength(1));
      expect(rows.single.text, 'solo');
    });

    test('are empty when the pack carried no sheet at all', () {
      expect(referenceRows(_kenKen(<String>[])), isEmpty);
    });

    test('cover every format, so a diagram list is never silently absent', () {
      // PROC-10 in miniature: a format whose diagrams nobody wrote would show a
      // card of bare text and no test would say so.
      for (final Puzzle puzzle in <Puzzle>[
        _kenKen(<String>['a', 'b', 'c']),
        KillerPuzzle(
          board: _board(),
          cages: const <Cage>[],
          tutorialSteps: const <String>[],
          referenceSheet: const <String>['a', 'b', 'c'],
        ),
        MagicSquarePuzzle(
          board: _board(),
          rowTargets: const <int>[6, 6, 6],
          columnTargets: const <int>[6, 6, 6],
          tutorialSteps: const <String>[],
          referenceSheet: const <String>['a', 'b', 'c'],
        ),
        _kakuro(<String>['a', 'b', 'c']),
        _sopa(<String>['a', 'b', 'c']),
      ]) {
        final List<ReferenceRow> rows = referenceRows(puzzle);
        expect(
          rows.every((ReferenceRow row) => row.diagram != null),
          isTrue,
          reason: '${puzzle.runtimeType} has a line with no diagram',
        );
      }
    });
  });

  group('the title of a reference card', () {
    test('names the format the player is looking at', () {
      expect(referenceCardTitle(_kenKen(<String>[])), 'KENKEN EN CORTO');
      expect(referenceCardTitle(_kakuro(<String>[])), 'KAKURO EN CORTO');
      expect(referenceCardTitle(_sopa(<String>[])), 'SOPA DE LETRAS EN CORTO');
    });

    test('and every format has a name of its own', () {
      final List<String> names = <String>[
        puzzleFormatName(_kenKen(<String>[])),
        puzzleFormatName(KillerPuzzle(
          board: _board(),
          cages: const <Cage>[],
          tutorialSteps: const <String>[],
          referenceSheet: const <String>[],
        )),
        puzzleFormatName(MagicSquarePuzzle(
          board: _board(),
          rowTargets: const <int>[6, 6, 6],
          columnTargets: const <int>[6, 6, 6],
          tutorialSteps: const <String>[],
          referenceSheet: const <String>[],
        )),
        puzzleFormatName(_kakuro(<String>[])),
        puzzleFormatName(_sopa(<String>[])),
      ];

      expect(names.toSet(), hasLength(names.length), reason: '$names');
    });
  });

  group('a diagram', () {
    test('never places a mark outside the grid it declares', () {
      // Every index is `row * size + column`, and an index past the last cell
      // would be dropped in silence by the widget that reads it.
      for (final ReferenceDiagram diagram in allReferenceDiagrams) {
        final int cells = diagram.size * diagram.size;
        expect(diagram.size, greaterThan(0));
        for (final int index in <int>[
          ...diagram.labels.keys,
          ...diagram.shaded,
          ...diagram.highlighted,
          ...diagram.cage,
        ]) {
          expect(index, inInclusiveRange(0, cells - 1),
              reason: 'index $index is off a ${diagram.size}×${diagram.size} grid');
        }
      }
    });

    test('carries a cage label only when it has a cage to hang it on', () {
      for (final ReferenceDiagram diagram in allReferenceDiagrams) {
        if (diagram.cageLabel != null) {
          expect(diagram.cage, isNotEmpty);
        }
      }
    });

    test('and the set of them is not empty', () {
      expect(allReferenceDiagrams, isNotEmpty);
    });
  });
}
