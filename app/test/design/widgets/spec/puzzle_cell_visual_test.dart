import 'package:akimath_app/design/tokens/brand_colors.dart';
import 'package:akimath_app/design/widgets/spec/puzzle_cell_visual.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the three kinds are told apart by fill', () {
    test('each one is a different colour', () {
      final Set<int> fills = <int>{
        for (final PuzzleCellKind kind in PuzzleCellKind.values)
          // ignore: deprecated_member_use
          resolvePuzzleCell(kind).background.value,
      };

      expect(fills, hasLength(PuzzleCellKind.values.length));
    });

    test('only an open cell may be filled in', () {
      expect(resolvePuzzleCell(PuzzleCellKind.open).selectable, isTrue);
      expect(resolvePuzzleCell(PuzzleCellKind.given).selectable, isFalse);
      expect(resolvePuzzleCell(PuzzleCellKind.blocked).selectable, isFalse);
    });
  });

  group('a selected cell is visibly the one being worked on', () {
    test('its fill differs from an unselected open cell', () {
      // The defect this fixes: selection was a ring in ink at 3 px, which is
      // the cage outline's colour and width, on the same edges — so a cell
      // enclosed by its cage was selectable with no visible selection at all.
      expect(
        resolvePuzzleCell(PuzzleCellKind.open, selected: true).background,
        isNot(resolvePuzzleCell(PuzzleCellKind.open).background),
      );
    });

    test('and from every other cell on the board', () {
      final Set<Object> fills = <Object>{
        for (final PuzzleCellKind kind in PuzzleCellKind.values)
          resolvePuzzleCell(kind).background,
        resolvePuzzleCell(PuzzleCellKind.open, selected: true).background,
      };

      expect(fills, hasLength(PuzzleCellKind.values.length + 1));
    });

    test('it is the yellow that already means "you are working here"', () {
      // `term_visual.dart` uses it for the hole in a stimulus and
      // `word_search_screen.dart` for the letters under a finger. A fourth
      // spelling of the same idea would be a fourth thing to keep in step.
      expect(
        resolvePuzzleCell(PuzzleCellKind.open, selected: true).background,
        BrandColors.yellow,
      );
    });

    test('a cell a player cannot fill is never highlighted', () {
      // A highlight on something that cannot change is an invitation the board
      // has no way to honour.
      for (final PuzzleCellKind kind in <PuzzleCellKind>[
        PuzzleCellKind.given,
        PuzzleCellKind.blocked,
      ]) {
        expect(
          resolvePuzzleCell(kind, selected: true).background,
          resolvePuzzleCell(kind).background,
          reason: '$kind changed when selected',
        );
      }
    });

    test('selection leaves the ink and the selectability alone', () {
      final PuzzleCellVisual plain = resolvePuzzleCell(PuzzleCellKind.open);
      final PuzzleCellVisual chosen =
          resolvePuzzleCell(PuzzleCellKind.open, selected: true);

      expect(chosen.ink, plain.ink);
      expect(chosen.selectable, plain.selectable);
    });
  });
}
