import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/design/widgets/verdict_ring.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    );

void main() {
  group('a verdict cannot be communicated by hue', () {
    test('the type has no colour accessor', () {
      // Enumerated by construction rather than by reflection: the members are
      // listed here, and a Color added to the type would have to be added to
      // this list too — at which point the assertion below fails.
      const Verdict correct = Verdict.correct;

      final List<Object?> surface = <Object?>[
        correct.outline,
        correct.glyph,
      ];

      for (final Object? member in surface) {
        expect(
          member,
          isNot(isA<Color>()),
          reason: 'Verdict exposed a Color; hue-only becomes expressible',
        );
      }
      expect(surface, hasLength(2), reason: 'the surface grew — re-check it');
    });

    test('success and error differ in shape', () {
      expect(Verdict.correct.outline, isNot(Verdict.wrong.outline));
      expect(Verdict.correct.glyph, isNot(Verdict.wrong.glyph));

      expect(Verdict.correct.outline, VerdictOutline.solid);
      expect(Verdict.wrong.outline, VerdictOutline.dashed);
      expect(Verdict.correct.glyph, BrandGlyph.check);
      expect(Verdict.wrong.glyph, BrandGlyph.alert);
    });

    test('the glyph is never optional', () {
      // The outline is a channel a widget may already have spent —
      // ItemTermTile's `unknown` is already dashed on five of six stimulus
      // screens. The glyph is the one nothing else has claimed (design D2).
      for (final Verdict verdict in Verdict.values) {
        expect(verdict.glyph, isNotNull);
      }
    });
  });

  group('the paint adapter differs in greyscale', () {
    testWidgets('the two rings differ in stroke pattern and in glyph',
        (WidgetTester tester) async {
      // Colour stripped on purpose: this is the reader BRD-1 is about, and
      // asserting `correct.outline != wrong.outline` alone would pass for any
      // two enum values (design D3).
      const Color mono = Color(0xFF000000);

      await tester.pumpWidget(
        _host(const VerdictRing(Verdict.correct, size: 44, color: mono)),
      );
      final bool correctIsDashed =
          find.byType(CustomPaint).evaluate().isNotEmpty;
      final BrandGlyph correctGlyph =
          tester.widget<BrandIcon>(find.byType(BrandIcon)).glyph;

      await tester.pumpWidget(
        _host(const VerdictRing(Verdict.wrong, size: 44, color: mono)),
      );
      final bool wrongIsDashed = find.byType(CustomPaint).evaluate().isNotEmpty;
      final BrandGlyph wrongGlyph =
          tester.widget<BrandIcon>(find.byType(BrandIcon)).glyph;

      expect(
        correctIsDashed,
        isNot(wrongIsDashed),
        reason: 'both rings drew the same stroke pattern',
      );
      expect(correctGlyph, isNot(wrongGlyph));
    });

    testWidgets('neither is distinguishable by fill alone',
        (WidgetTester tester) async {
      const Color mono = Color(0xFF000000);

      Future<Color?> fillOf(Verdict verdict) async {
        await tester.pumpWidget(
          _host(VerdictRing(verdict, size: 44, color: mono)),
        );
        final Container container = tester.widget<Container>(
          find.descendant(
            of: find.byType(VerdictRing),
            matching: find.byType(Container),
          ),
        );
        return (container.decoration! as BoxDecoration).color;
      }

      // Same fill for both: the distinction has to come from the other two
      // channels or it does not exist.
      expect(await fillOf(Verdict.correct), await fillOf(Verdict.wrong));
    });
  });
}
