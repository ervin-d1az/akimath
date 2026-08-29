import 'package:akimath_app/design/icons/brand_icon.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/candy_surface.dart';
import 'package:akimath_app/design/widgets/streak_badge.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) =>
    tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: child),
        ),
      ),
    );

/// What `CenteredStateView` leaves its `kicker` on the 390 px design phone:
/// the viewport less `BrandShape.space4` on each side.
const double _kickerWidth = 390 - 2 * BrandShape.space4;

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

    testWidgets('fits the width `4.12` gives it at textScaler 1.3',
        (WidgetTester tester) async {
      // **350 px is measured, not chosen.** It is what `CenteredStateView`
      // leaves a kicker on the 390 px design phone, once its own
      // `BrandShape.space4` is taken off each side. Registering `4.12` is what
      // reported it: *A RenderFlex overflowed by 42 pixels on the right*, the
      // relevant widget named as `streak_badge.dart`'s own `Row`.
      //
      // The unit wraps rather than being clipped or shrunk: `días en juego`
      // ellipsised to `días en…` loses the sentence, and scaling the type down
      // spends exactly the size the reader asked for.
      await pump(
        tester,
        const SizedBox(
          width: _kickerWidth,
          child: Center(child: StreakBadge(days: 13)),
        ),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('and is untouched at the size the design drew it',
        (WidgetTester tester) async {
      // The other half, and the one that says the fix costs nothing: a loose
      // `Flexible` is inert while its child already fits, so the drawn
      // instance keeps the width it has always had. Without this, "it fits at
      // 1.3" is satisfied by any amount of damage to the 1.0 case.
      //
      // Compared against the badge's own unconstrained width rather than
      // against a number typed here, because a literal would be the test font's
      // metrics recorded as if they were a design decision.
      await pump(tester, const StreakBadge(days: 13));
      final double wanted = tester.getSize(find.byType(StreakBadge)).width;
      expect(wanted, lessThan(_kickerWidth));

      await pump(
        tester,
        const SizedBox(
          width: _kickerWidth,
          child: Center(child: StreakBadge(days: 13)),
        ),
      );

      expect(tester.getSize(find.byType(StreakBadge)).width, wanted);
    });
  });
}
