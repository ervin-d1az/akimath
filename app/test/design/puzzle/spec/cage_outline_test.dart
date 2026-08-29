import 'package:akimath_app/design/painting/spec/dash_spec.dart';
import 'package:akimath_app/design/puzzle/spec/cage_outline.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two constants, and the equality the painter's `shouldRepaint` rests on.
///
/// **These assertions are not the gate, and saying so is the point.** They read
/// this file and pass whatever any screen draws — which is exactly how the
/// round cap was certified for weeks while the Killer board painted KenKen's
/// `6 4`. What holds the drawing to these values is
/// `puzzle_screen_test.dart`'s *a cage is drawn in its own format's outline*,
/// which reaches the painter through a pumped board, and
/// `cage_edge_painter_test.dart`, which reads the cap off a `Paint`.
void main() {
  group('the two formats are told apart by their dash', () {
    test('KenKen is 2.5px pink, dashed 6 on 4 off with a square cap', () {
      expect(CageOutline.kenKen.dash, DashSpec.kenKenCage);
      expect(CageOutline.kenKen.dash.cap, DashCap.butt);
      expect(CageOutline.kenKen.color, BrandColors.pink);
      expect(CageOutline.kenKen.strokeWidth, BrandShape.borderWidthCage);
    });

    test('Killer is 2 on 5 off with a round cap, which reads as dots', () {
      expect(CageOutline.killer.dash, DashSpec.killerCage);
      expect(CageOutline.killer.dash.cap, DashCap.round);
      expect(CageOutline.killer.color, BrandColors.pink);
      expect(CageOutline.killer.strokeWidth, BrandShape.borderWidthCage);
    });

    test('and the two are not the same outline', () {
      // The whole defect in one line: for as long as both call sites named
      // `DashSpec.kenKenCage`, the board could not tell these apart.
      expect(CageOutline.killer, isNot(CageOutline.kenKen));
    });
  });

  group('a miniature is the same cage drawn thinner', () {
    test('it keeps the pattern and the colour and steps the stroke down', () {
      const CageOutline board = CageOutline.killer;
      final CageOutline diagram = board.miniature;

      expect(diagram.dash, board.dash);
      expect(diagram.color, board.color);
      expect(diagram.strokeWidth, BrandShape.borderWidthHairline);
      expect(diagram.strokeWidth, lessThan(board.strokeWidth));
    });

    test('two formats stay distinguishable once shrunk', () {
      // A miniature that dropped the pattern would make every reference
      // diagram show the same cage, which is the board's defect on the card.
      expect(
        CageOutline.killer.miniature,
        isNot(CageOutline.kenKen.miniature),
      );
    });
  });

  group('an outline compares by value', () {
    test('two miniatures of the same outline are equal', () {
      // `miniature` builds a new instance on every build, and
      // `CageEdgePainter.shouldRepaint` compares outlines. Identity here would
      // repaint every diagram on the card on every frame.
      expect(
        CageOutline.kenKen.miniature,
        CageOutline.kenKen.miniature,
      );
      expect(
        CageOutline.kenKen.miniature.hashCode,
        CageOutline.kenKen.miniature.hashCode,
      );
    });
  });
}
