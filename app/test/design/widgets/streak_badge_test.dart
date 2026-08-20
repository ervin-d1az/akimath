import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/candy_surface.dart';
import 'package:akimath_app/design/widgets/streak_badge.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

void main() {
  group('the streak badge', () {
    testWidgets('carries the run, the unit and the flame', (WidgetTester tester) async {
      await pump(tester, const StreakBadge(days: 13));

      expect(find.text('13'), findsOneWidget);
      expect(find.text('días en juego'), findsOneWidget);
      expect(
        tester.widget<BrandIcon>(find.byType(BrandIcon)).glyph,
        BrandGlyph.flame,
      );
    });

    testWidgets('one day is singular', (WidgetTester tester) async {
      // `1 días en juego` is the sentence a count that never learned to
      // agree prints, and it is the first thing a reader notices.
      await pump(tester, const StreakBadge(days: 1));

      expect(find.text('día en juego'), findsOneWidget);
    });

    testWidgets('is yellow and raised, not a card', (WidgetTester tester) async {
      await pump(tester, const StreakBadge(days: 13));

      final CandySurface surface =
          tester.widget<CandySurface>(find.byType(CandySurface));
      expect(surface.background, BrandColors.yellow);
      expect(surface.shadowOffset, BrandShape.shadowButton);
    });

    testWidgets('reads as one thing to a screen reader', (WidgetTester tester) async {
      await pump(tester, const StreakBadge(days: 13));

      expect(find.bySemanticsLabel('13 días en juego'), findsOneWidget);
    });
  });
}
