import 'package:akimath_app/design/painting/spec/dash_spec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a pattern that does not divide the perimeter evenly', () {
    test('the final segment is truncated and never overruns', () {
      // 100 is deliberately not a multiple of the 18px period.
      final List<DashSegment> segments =
          const DashSpec(on: 9, off: 9).segments(pathLength: 100);

      expect(segments.last.end, lessThanOrEqualTo(100));
      expect(segments.every((DashSegment s) => s.end <= 100), isTrue);
      expect(segments.every((DashSegment s) => s.end > s.start), isTrue);
    });

    test('segments march in order and never overlap', () {
      final List<DashSegment> segments =
          const DashSpec(on: 9, off: 9).segments(pathLength: 100);

      double previousEnd = 0;
      for (final DashSegment segment in segments) {
        expect(segment.start, greaterThanOrEqualTo(previousEnd));
        previousEnd = segment.end;
      }
    });

    test('a path shorter than one dash still draws something', () {
      // Otherwise a small cage or a short edge silently loses its outline.
      final List<DashSegment> segments =
          const DashSpec(on: 9, off: 9).segments(pathLength: 4);

      expect(segments, hasLength(1));
      expect(segments.single.start, 0);
      expect(segments.single.end, 4);
    });
  });

  group('the three patterns the documents use', () {
    // Stated as counts on purpose: "they produce different segment lists" is
    // true of any implementation that reads its own arguments and can never go
    // red. And asserted through the **named constants**, not through a freshly built
    // pattern. Building one here would test the arithmetic and leave the three
    // values the app actually uses pinned by nothing — which is what a
    // falsification found: changing `kenKenCage` to 6/5 left the suite green.

    test('KenKen is 6/4 and gives 10 segments over 100px', () {
      expect(DashSpec.kenKenCage.on, 6);
      expect(DashSpec.kenKenCage.off, 4);
      expect(DashSpec.kenKenCage.segments(pathLength: 100), hasLength(10));
    });

    test('Killer is 2/5, round-capped, and gives 15 segments over 100px', () {
      expect(DashSpec.killerCage.on, 2);
      expect(DashSpec.killerCage.off, 5);
      expect(DashSpec.killerCage.cap, DashCap.round);
      expect(DashSpec.killerCage.segments(pathLength: 100), hasLength(15));
    });

    test('the locked edge is 9/9 and gives 6 segments over 100px', () {
      expect(DashSpec.locked.on, 9);
      expect(DashSpec.locked.off, 9);
      expect(DashSpec.locked.segments(pathLength: 100), hasLength(6));
    });

    test('the default cap is butt, not round', () {
      expect(DashSpec.locked.cap, DashCap.butt);
      expect(DashSpec.kenKenCage.cap, DashCap.butt);
    });
  });

  group('the segmentation is a function of its arguments', () {
    test('the same request twice gives the same answer', () {
      const DashSpec spec = DashSpec(on: 6, off: 4);
      final List<DashSegment> once = spec.segments(pathLength: 137.5);
      final List<DashSegment> twice = spec.segments(pathLength: 137.5);

      expect(once.length, twice.length);
      expect(once.first.end, twice.first.end);
      expect(once.last.end, twice.last.end);
    });

    test('a zero-length path yields nothing rather than throwing', () {
      expect(
        const DashSpec(on: 6, off: 4).segments(pathLength: 0),
        isEmpty,
      );
    });
  });
}
