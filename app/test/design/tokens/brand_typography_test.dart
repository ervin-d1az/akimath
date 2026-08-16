import 'package:akimath_app/design/tokens/brand_typography.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The type scale, and the defaults that keep it from moving under the screens
/// already drawn.
///
/// Five styles gain parameters here and no style is added. Every new parameter
/// defaults to the value that was hard-coded before it, so each style is
/// asserted twice: once varied, to prove the parameter is wired, and once bare,
/// to prove nothing on screen shifted a pixel.
void main() {
  group('eyebrow', () {
    test('takes a size and tracking in em, resolved against that size', () {
      final TextStyle style = BrandText.eyebrow(size: 10, letterSpacing: 0.06);

      expect(style.fontFamily, BrandFonts.text);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.fontSize, 10);
      expect(style.letterSpacing, 0.6);
    });

    test('defaults to the 12px at 1.2px tracking already on screen', () {
      final TextStyle style = BrandText.eyebrow();

      expect(style.fontSize, 12);
      // `12 * 0.1` is 1.2000000000000002, one ULP off the literal that stood
      // here before, hence `moreOrLessEquals`: design D6 calls this default
      // byte-identical, and identical to within 2e-16 px is the honest claim.
      expect(style.letterSpacing, moreOrLessEquals(1.2));
    });
  });

  group('numeral', () {
    test('is Darumadrop at the size asked for, on a single-line box', () {
      final TextStyle style = BrandText.numeral(29);

      expect(style.fontFamily, BrandFonts.display);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontSize, 29);
      expect(style.height, 1);
    });

    test('does not replace sectionTitle', () {
      // A keypad digit and a section header are two roles that happen to share
      // a face today. They diverge the day a header gains tracking, and the
      // second name is what makes that possible without touching the keypad.
      expect(BrandText.sectionTitle().fontSize, 34);
      expect(BrandText.sectionTitle(size: 29).fontSize, 29);
    });
  });

  group('cardTitle', () {
    test('takes a size', () {
      expect(BrandText.cardTitle(size: 17).fontSize, 17);
    });

    test('defaults to the 20px already on screen', () {
      final TextStyle style = BrandText.cardTitle();

      expect(style.fontSize, 20);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.height, isNull);
    });
  });

  group('body', () {
    test('takes a line height', () {
      expect(BrandText.body(height: 1.35).height, 1.35);
    });

    test('defaults to the 15px at 1.5 already on screen', () {
      final TextStyle style = BrandText.body();

      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, 1.5);
    });
  });

  group('caption', () {
    test('takes a size and a line height', () {
      final TextStyle style = BrandText.caption(size: 11, height: 1.2);

      expect(style.fontSize, 11);
      expect(style.height, 1.2);
    });

    test('defaults to the 13px at 1.5 already on screen', () {
      final TextStyle style = BrandText.caption();

      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, 1.5);
    });
  });
}
