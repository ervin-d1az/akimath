/// Which cages a puzzle draws, and the outline they are drawn in.
///
/// **The design layer names the outlines and the feature maps the model onto
/// them**, which is the seam `puzzle_cell_visual.dart` already keeps:
/// `design/` knows what a cage looks like and nothing about packs, and this
/// file knows the five formats and none of the geometry.
///
/// **One switch, and it is exhaustive.** The two facts travel together because
/// a board with cages and no outline, or an outline and no cages, is a pairing
/// nobody can act on — and `Puzzle` is sealed, so a sixth format is a compile
/// error here rather than a board that quietly draws somebody else's dash. That
/// is the defect this file exists to make impossible: `PuzzleScreen` read the
/// cages off any `CagedPuzzle` and the widget beneath it named `kenKenCage`
/// itself, so Killer drew KenKen's outline with every suite green.
library;

import '../../../content/model/puzzle.dart';
import '../../../design/puzzle/spec/cage_outline.dart';

/// A board's cages and how they are outlined. [outline] is null exactly when
/// there are no cages.
typedef CagePlan = ({List<Cage> cages, CageOutline? outline});

/// What [puzzle] puts on its board.
CagePlan cagePlanFor(Puzzle puzzle) => switch (puzzle) {
      KenKenPuzzle(:final List<Cage> cages) =>
        (cages: cages, outline: CageOutline.kenKen),
      KillerPuzzle(:final List<Cage> cages) =>
        (cages: cages, outline: CageOutline.killer),
      MagicSquarePuzzle() || KakuroPuzzle() || WordSearchPuzzle() =>
        (cages: <Cage>[], outline: null),
    };
