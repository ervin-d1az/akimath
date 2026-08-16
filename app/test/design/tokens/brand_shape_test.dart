import 'package:akimath_app/design/tokens/brand_shape.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape scale, asserted value by value.
///
/// Twelve constants land here at once and none of them is reachable from a
/// screen yet, so nothing else in the suite would notice a mistyped radius or a
/// transposed offset until a screen six changes from now drew it wrong. This is
/// the file that notices.
void main() {
  group('radii', () {
    test('the scale names every surface radius the designs draw', () {
      expect(BrandShape.radiusSlot, 12);
      expect(BrandShape.radiusChip, 14);
      expect(BrandShape.radiusControl, 16);
      expect(BrandShape.radiusButton, 20);
      expect(BrandShape.radiusCardSmall, 22);
      expect(BrandShape.radiusPanel, 24);
      expect(BrandShape.radiusCardMedium, 26);
      expect(BrandShape.radiusSheet, 32);
    });

    test('nothing that already had a name was renamed or moved', () {
      // Widening the scale must not move a surface that is already drawn:
      // `candy_surface.dart` and the app icon read these four.
      expect(BrandShape.radiusPill, 18);
      expect(BrandShape.radiusCard, 28);
      expect(BrandShape.radiusIconTile, 20);
      expect(BrandShape.radiusScreen, 42);
    });

    test('two roles sharing a value keep two names', () {
      // The app-icon tile is drawn at 240px in the lockup and the button at
      // h60 in the flow. Equal values are not a duplication; one shared name
      // would move both the day either one moves.
      expect(BrandShape.radiusButton, BrandShape.radiusIconTile);
    });
  });

  group('border widths', () {
    test('the scale names the two strokes thinner than the standard outline',
        () {
      expect(BrandShape.borderWidthSmallSurface, 2.5);
      expect(BrandShape.borderWidthField, 2);
    });

    test('the two strokes already on screen are unchanged', () {
      expect(BrandShape.borderWidth, 3);
      expect(BrandShape.iconBorderWidth, 7);
    });
  });

  group('shadow offsets', () {
    test('the most common shadow in the app has a name', () {
      expect(BrandShape.shadowButton, const Offset(4, 6));
    });

    test('the dot shadow has a name', () {
      expect(BrandShape.shadowDot, const Offset(2, 3));
    });

    test('the four offsets already on screen are unchanged', () {
      expect(BrandShape.shadowPill, const Offset(3, 4));
      expect(BrandShape.shadowTile, const Offset(3, 5));
      expect(BrandShape.shadowCard, const Offset(5, 7));
      expect(BrandShape.shadowIcon, const Offset(6, 8));
    });
  });
}
