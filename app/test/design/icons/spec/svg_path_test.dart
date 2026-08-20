import 'dart:ui';

import 'package:akimath_app/design/icons/spec/svg_path.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bounds, not "it did not throw".
///
/// **A path parser's failure mode is a plausible wrong curve, not a crash.**
/// A mis-reflected smooth-cubic control point draws a shape that renders
/// happily and is not the design's. So every assertion here is about where the
/// geometry actually lands.
Rect boundsOf(String d) => parseSvgPath(d).getBounds();

void near(double actual, double expected, {double within = 0.01}) =>
    expect((actual - expected).abs(), lessThan(within),
        reason: '$actual is not within $within of $expected');

void main() {
  group('the commands the transcribed glyphs actually use', () {
    test('absolute move and relative line', () {
      // `back`: M14 5l-7 7 7 7
      final Rect box = boundsOf('M14 5l-7 7 7 7');
      near(box.left, 7);
      near(box.top, 5);
      near(box.right, 14);
      near(box.bottom, 19);
    });

    test('an implicit repeat continues the previous command', () {
      // `check`: M4 11l4 4 8-9 — the `8-9` is a second `l`, not a new command.
      final Rect box = boundsOf('M4 11l4 4 8-9');
      near(box.left, 4);
      near(box.right, 16);
      near(box.top, 6);
      near(box.bottom, 15);
    });

    test('a negative number needs no separator before it', () {
      expect(boundsOf('M0 0l10-10'), boundsOf('M0 0 l 10 -10'));
    });

    test('a leading-dot number parses', () {
      // `alert`: M10 15h.01 — a dot with no integer part.
      final Rect box = boundsOf('M10 15h.01');
      near(box.left, 10);
      near(box.right, 10.01);
    });

    test('horizontal and vertical, both cases', () {
      // `undo` uses a relative `h` and then an absolute `H`.
      final Rect box = boundsOf('M4 8h9V20H2');
      near(box.left, 2);
      near(box.right, 13);
      near(box.top, 8);
      near(box.bottom, 20);
    });

    test('close returns the pen to the subpath start', () {
      // `pencil` ends in `Z`. What that has to do is put the current point back
      // at the subpath's origin, which is only observable in what a following
      // command draws from.
      //
      // Not asserted through `Path.contains`: Flutter closes an open subpath
      // implicitly for hit testing, so a parser that ignored `Z` entirely would
      // pass that.
      final Rect afterClose = parseSvgPath('M10 10L20 10L20 20Zl-5 5').getBounds();

      near(afterClose.left, 5, within: 0.01);
      near(afterClose.top, 10, within: 0.01);
      expect(afterClose.bottom, closeTo(20, 0.01));
    });

    test('a second move starts a new subpath rather than a line', () {
      // `mapsTo`: M3 12h20M17 5l6 7-6 7 — the stem and the head are separate.
      final Rect box = boundsOf('M3 12h20M17 5l6 7-6 7');
      near(box.left, 3);
      near(box.right, 23);
      near(box.top, 5);
      near(box.bottom, 19);
    });
  });

  group('curves, where a wrong answer still looks like a curve', () {
    test('a relative cubic lands where its endpoint says', () {
      // `flame`'s opening: M12 3c3 4 6 5.5 6 9 — ends at (18, 12).
      final Rect box = boundsOf('M12 3c3 4 6 5.5 6 9');
      near(box.left, 12);
      near(box.right, 18);
      near(box.top, 3);
      near(box.bottom, 12);
    });

    test('a smooth cubic reflects the previous control point', () {
      // `navProfile`: M5 22c1.6-4 4.4-5.6 8-5.6s6.4 1.6 8 5.6
      //
      // **The one command whose mistake is invisible.** An `s` that ignores the
      // reflection draws a curve — a different, smooth, entirely plausible one.
      // Reflecting c2=(9.4,16.4) about the endpoint (13,16.4) gives (16.6,16.4);
      // dropping the reflection would use the endpoint itself and pull the
      // second hump flat.
      final Path reflected = parseSvgPath('M5 22c1.6-4 4.4-5.6 8-5.6s6.4 1.6 8 5.6');
      final Path spelledOut = parseSvgPath(
        'M5 22C6.6 18 9.4 16.4 13 16.4C16.6 16.4 19.4 18 21 22',
      );

      final Rect a = reflected.getBounds();
      final Rect b = spelledOut.getBounds();
      near(a.left, b.left);
      near(a.top, b.top);
      near(a.right, b.right);
      near(a.bottom, b.bottom);
    });

    test('a smooth cubic with no cubic before it uses the current point', () {
      // The SVG rule for an `s` that opens a curve run. Nothing transcribed
      // does this, and a parser that read a stale control point from the
      // previous glyph would only show it here.
      expect(
        boundsOf('M0 0s5 0 10 10').width,
        closeTo(boundsOf('M0 0c0 0 5 0 10 10').width, 0.01),
      );
    });
  });

  group('arcs, and the flag packing that breaks naive tokenizers', () {
    test('flags are single characters, so 1-12 is a flag and a number', () {
      // `flame`: a6 6 0 0 1-12 0 — sweep flag `1`, then dx `-12`. A tokenizer
      // reading a full number here consumes `1-12` or `1` and then trips.
      final Rect box = boundsOf('M18 12a6 6 0 0 1-12 0');
      near(box.left, 6);
      near(box.right, 18);
      near(box.top, 12);
      // A half-circle of radius 6 below the chord.
      near(box.bottom, 18, within: 0.2);
    });

    test('the large-arc flag is honoured', () {
      // `undo`: a5 5 0 1 1 0 10 — large arc, so it goes the long way round.
      // A chord shorter than the diameter, or both flags draw the same
      // semicircle and the assertion is vacuous — which the first version of
      // this test was, at chord 10 on radius 5.
      final Rect large = boundsOf('M13 8a5 5 0 1 1 0 6');
      final Rect small = boundsOf('M13 8a5 5 0 0 1 0 6');

      expect(large.width, greaterThan(small.width),
          reason: 'the long way round bulges further');
    });

    test('an absolute arc is not read as a relative one', () {
      final Rect box = boundsOf('M0 10A10 10 0 0 1 20 10');
      near(box.left, 0);
      near(box.right, 20);
    });

    test('a two-arc run repeats implicitly', () {
      // `wifiOff` chains arcs; a repeat that restarted the command would draw
      // one arc and drop the rest.
      final Rect box = boundsOf('M3 7a13 13 0 0 1 14 0');
      near(box.left, 3);
      near(box.right, 17);
    });
  });

  group('what it refuses', () {
    test('an unknown command is an error, not a silent skip', () {
      // A glyph transcribed with a typo must fail loudly at its test rather
      // than draw two thirds of itself on a screen.
      expect(() => parseSvgPath('M0 0Q5 5 10 0'), throwsFormatException);
    });

    test('a path that does not begin with a move is refused', () {
      expect(() => parseSvgPath('L10 10'), throwsFormatException);
    });

    test('a command missing arguments is refused', () {
      expect(() => parseSvgPath('M0 0L10'), throwsFormatException);
    });

    test('an empty path is refused', () {
      expect(() => parseSvgPath('   '), throwsFormatException);
    });
  });
}
