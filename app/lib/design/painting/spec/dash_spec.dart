/// Dash segmentation, as arithmetic.
///
/// Given a pattern and how long a path is, this returns where the ink goes. It
/// never sees a `Path`, never calls `computeMetrics`, never touches a `Canvas`
/// — the painter beside it does all three. That is what lets the test assert
/// exact segment counts with no fake canvas.
///
/// The dash exists because of BRD-1: success and error must be distinguishable
/// by **shape**, not only hue, since deuteranopia collapses green and coral.
/// Solid means right, dashed means wrong, and that has to survive a reader who
/// cannot tell the two colours apart.
library;

/// How a dash ends.
enum DashCap {
  /// Square. The default, and what the KenKen and locked-edge patterns use.
  butt,

  /// Rounded. The Killer cage's `2 5` pattern reads as dots rather than dashes.
  round,
}

/// One run of ink along a path, measured from the path's start.
class DashSegment {
  const DashSegment({required this.start, required this.end});

  final double start;
  final double end;

  double get length => end - start;
}

/// A dash pattern: [on] pixels of ink, [off] pixels of gap, repeating.
class DashSpec {
  const DashSpec({required this.on, required this.off, this.cap = DashCap.butt})
      : assert(on > 0, 'a dash with no ink is a gap'),
        assert(off > 0, 'a dash with no gap is a solid line');

  /// The KenKen cage outline.
  static const DashSpec kenKenCage = DashSpec(on: 6, off: 4);

  /// The Killer cage outline, which reads as dots.
  static const DashSpec killerCage =
      DashSpec(on: 2, off: 5, cap: DashCap.round);

  /// A locked edge, an empty-state placeholder, a focused slot.
  static const DashSpec locked = DashSpec(on: 9, off: 9);

  final double on;
  final double off;
  final DashCap cap;

  double get _period => on + off;

  /// Where the ink goes along a path of [pathLength].
  ///
  /// The last segment is **truncated** at the end of the path rather than
  /// overrunning it, which is the case a pattern that divides evenly never
  /// exercises — and no pattern in this design divides evenly into anything.
  List<DashSegment> segments({required double pathLength}) {
    if (pathLength <= 0) {
      return const <DashSegment>[];
    }

    final List<DashSegment> out = <DashSegment>[];
    for (double start = 0; start < pathLength; start += _period) {
      final double end = start + on;
      out.add(
        DashSegment(
          start: start,
          // A path shorter than one dash still gets ink: a short cage edge that
          // silently lost its outline would read as solid, which under BRD-1 is
          // the opposite verdict.
          end: end < pathLength ? end : pathLength,
        ),
      );
    }
    return out;
  }
}
