import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/before_after_counters.dart';
import 'package:akimath_app/design/widgets/candy_surface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

void main() {
  group('what was against what is', () {
    testWidgets('draws both values under their captions', (WidgetTester tester) async {
      await pump(
        tester,
        const BeforeAfterCounters(
          before: 13,
          beforeCaption: 'AYER',
          after: 1,
          afterCaption: 'HOY',
        ),
      );

      expect(find.text('13'), findsOneWidget);
      expect(find.text('AYER'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('HOY'), findsOneWidget);
    });

    testWidgets('the past is flat and the present is raised', (WidgetTester tester) async {
      // **The whole argument of the screen, and the thing a later tidy-up
      // would "fix".** The contrast is not decoration: a shadow on both boxes
      // would draw two equal facts, and one of them is over.
      await pump(
        tester,
        const BeforeAfterCounters(
          before: 13,
          beforeCaption: 'AYER',
          after: 1,
          afterCaption: 'HOY',
        ),
      );

      final List<CandySurface> boxes =
          tester.widgetList<CandySurface>(find.byType(CandySurface)).toList();
      expect(boxes, hasLength(2));

      expect(boxes.first.shadowOffset, Offset.zero, reason: 'the past is flat');
      expect(boxes.first.background, BrandColors.surface);
      expect(boxes.first.borderColor, BrandColors.muted);

      expect(boxes.last.shadowOffset, BrandShape.shadowTile,
          reason: 'the present is raised');
      expect(boxes.last.background, BrandColors.yellow);
      expect(boxes.last.borderColor, BrandColors.ink);
    });

    testWidgets('the arrow between them is not a comparison', (WidgetTester tester) async {
      // `13 › 1` would read as `13 > 1` — a true statement here, and a false
      // one the day the pair runs the other way. `mapsTo` is the glyph that
      // means *becomes*.
      await pump(
        tester,
        const BeforeAfterCounters(
          before: 13,
          beforeCaption: 'AYER',
          after: 1,
          afterCaption: 'HOY',
        ),
      );

      expect(find.text('›'), findsNothing);
    });
  });
}
