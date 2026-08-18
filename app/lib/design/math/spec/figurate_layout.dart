/// Where the dots of a figurate number go.
///
/// **Pure geometry.** A count in, positions out, in a unit box — no `Canvas`,
/// no widget, no size. `dart:ui`'s `Offset` is a value type with no rendering
/// attached, which is the same licence `fraction_metrics.dart` takes next door.
///
/// A figurate number is one you can arrange into a regular figure: 1, 3, 6, 10
/// make triangles, 1, 4, 9, 16 make squares. The frozen payload carries only
/// the **count** — deliberately, since a shape is a rendering decision — so
/// choosing the arrangement is this file's job and it is the whole puzzle:
/// draw 6 as a 3×2 block and the learner sees no triangle to continue.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

/// The dots of one figure, and how big to draw them.
class FigurateLayout {
  const FigurateLayout({required this.dots, required this.radius});

  /// Dot centres in a unit box — both coordinates in `[0, 1]`, y downward, in
  /// reading order. The caller multiplies by whatever box it has.
  final List<Offset> dots;

  /// Dot radius as a fraction of that same box.
  ///
  /// **It shrinks as the count grows**, which is what keeps a figure of ten
  /// inside the same square as a figure of one instead of spilling out of it.
  final double radius;
}

/// How much of a cell a dot fills. Under 1 so neighbours never touch — dots
/// that touch read as a blob and stop being countable, which is the one thing
/// this figure has to be.
const double _dotFill = 0.62;

/// The triangular root of [count], or null if it is not triangular.
///
/// `k(k+1)/2 == count`. Solved rather than searched, then verified — the
/// inverse of a quadratic in floating point is not something to trust on its
/// own, and the check costs one multiply.
int? triangularRoot(int count) {
  if (count < 1) {
    return null;
  }
  final int k = ((math.sqrt(8 * count + 1) - 1) / 2).round();
  return k * (k + 1) ~/ 2 == count ? k : null;
}

/// The square root of [count] if it is a perfect square, else null.
int? squareRoot(int count) {
  if (count < 1) {
    return null;
  }
  final int k = math.sqrt(count).round();
  return k * k == count ? k : null;
}

/// The arrangement for [count] dots.
///
/// Triangular is tried first and squares second, because a count that is both
/// — 1, and only 1 — draws the same either way, while the authored figures the
/// design names (1, 3, 6, 10) are triangular and would otherwise never find
/// their shape. Anything that is neither falls back to a centred grid, which is
/// not a figurate figure at all; the reader refuses such packs, and this exists
/// so that a bug upstream is an ugly figure rather than a crash.
FigurateLayout figurateLayout(int count) {
  if (count < 1) {
    return const FigurateLayout(dots: <Offset>[], radius: 0);
  }

  final int? triangle = triangularRoot(count);
  if (triangle != null) {
    return _rows(<int>[for (int row = 0; row < triangle; row++) row + 1]);
  }

  final int? square = squareRoot(count);
  if (square != null) {
    return _rows(<int>[for (int row = 0; row < square; row++) square]);
  }

  // Neither. As square a block as the count allows, so the fallback at least
  // stays inside its box.
  final int columns = math.sqrt(count).ceil();
  final int full = count ~/ columns;
  final int remainder = count % columns;
  return _rows(<int>[
    for (int row = 0; row < full; row++) columns,
    if (remainder > 0) remainder,
  ]);
}

/// Lays out rows of the given widths, each row centred over the widest.
///
/// The unit box is divided into `max(rows, widest)` cells on both axes so the
/// figure keeps its aspect: a four-row triangle is as tall as it is wide, and
/// scaling it to fit a square box does not stretch it.
FigurateLayout _rows(List<int> widths) {
  final int widest = widths.reduce(math.max);
  final int cells = math.max(widths.length, widest);
  final double step = 1 / cells;

  // Centres the figure vertically too, so a wide short figure sits in the
  // middle of its box rather than against the top edge.
  final double top = (cells - widths.length) / 2 * step;

  return FigurateLayout(
    dots: <Offset>[
      for (int row = 0; row < widths.length; row++)
        for (int column = 0; column < widths[row]; column++)
          Offset(
            0.5 + (column - (widths[row] - 1) / 2) * step,
            top + (row + 0.5) * step,
          ),
    ],
    radius: step / 2 * _dotFill,
  );
}
