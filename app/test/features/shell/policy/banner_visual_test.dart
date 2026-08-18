import 'package:akimath_app/design/icons/spec/brand_glyph.dart';
import 'package:akimath_app/features/shell/policy/banner_visual.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a banner is never distinguished by hue alone', () {
    test('the two kinds carry different glyphs', () {
      // BRD-1's problem in a different widget: coral against yellow is
      // unreadable to a reader who cannot separate them.
      expect(
        resolveBannerVisual(BannerKind.error).glyph,
        isNot(resolveBannerVisual(BannerKind.notice).glyph),
      );
    });

    test('the no-connection banner carries wifi-off, not alert', () {
      expect(resolveBannerVisual(BannerKind.notice).glyph, BrandGlyph.wifiOff);
      expect(resolveBannerVisual(BannerKind.error).glyph, BrandGlyph.alert);
    });

    test('every kind resolves a glyph — none is optional', () {
      for (final BannerKind kind in BannerKind.values) {
        expect(resolveBannerVisual(kind).glyph, isNotNull);
      }
    });

    test('the visual carries no Color', () {
      for (final BannerKind kind in BannerKind.values) {
        final BannerVisual visual = resolveBannerVisual(kind);
        for (final Object? member in <Object?>[visual.glyph, visual.tone]) {
          expect(member.toString(), isNot(contains('Color')));
        }
      }
    });
  });

  group('the hue encodes whose fault it is', () {
    test('there is no offline kind — a lost connection is a notice', () {
      // "Sin conexión no es un error del usuario: va en amarillo."
      expect(
        BannerKind.values.map((BannerKind k) => k.name),
        <String>['error', 'notice'],
      );
      expect(resolveBannerVisual(BannerKind.notice).tone, BannerTone.notice);
    });
  });

  group('placement is a skin, not a second widget', () {
    test('both placements exist on one type', () {
      // K7: the two skins are absorbed by a placement rather than producing a
      // second banner widget that drifts from the first.
      expect(BannerPlacement.values, hasLength(2));
    });
  });
}
