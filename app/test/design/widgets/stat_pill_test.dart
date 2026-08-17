import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/stat_pill.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

BoxDecoration _decorationOf(WidgetTester tester, Type of) =>
    tester.widget<Container>(
      find.descendant(of: find.byType(of), matching: find.byType(Container)),
    ).decoration! as BoxDecoration;

void main() {
  group('the pill ships both sizes', () {
    test('header is h48 r24 shadow (3,5); hero is r22 shadow (4,6)', () {
      expect(StatPillSize.header.height, 48);
      expect(StatPillSize.header.radius, 24);
      expect(StatPillSize.header.shadow, BrandShape.shadowTile);

      expect(StatPillSize.hero.radius, 22);
      expect(StatPillSize.hero.shadow, BrandShape.shadowButton);
      expect(
        StatPillSize.hero.height,
        isNull,
        reason: 'hero takes its height from the call site',
      );
    });

    testWidgets('header renders at its own fixed height',
        (WidgetTester tester) async {
      await _pump(tester, const StatPill(child: Text('1 180')));
      expect(tester.getSize(find.byType(StatPill)).height, 48);
      expect(_decorationOf(tester, StatPill).border!.top.width,
          BrandShape.borderWidth);
    });
  });

  group('the hero size carries the two screens that forced K8', () {
    testWidgets('4.12 streak badge: h56 on yellow', (WidgetTester tester) async {
      await _pump(
        tester,
        const StatPill(
          size: StatPillSize.hero,
          height: 56,
          background: BrandColors.yellow,
          child: Text('7'),
        ),
      );

      expect(tester.getSize(find.byType(StatPill)).height, 56);
      final BoxDecoration decoration = _decorationOf(tester, StatPill);
      expect(decoration.color, BrandColorRole.highlight.color);
      expect(decoration.borderRadius, BorderRadius.circular(22));
      expect(decoration.boxShadow!.single.offset, BrandShape.shadowButton);
    });

    testWidgets('0.6 rating chip: h64 on the default background',
        (WidgetTester tester) async {
      await _pump(
        tester,
        const StatPill(
          size: StatPillSize.hero,
          height: 64,
          child: Text('1 180'),
        ),
      );

      expect(tester.getSize(find.byType(StatPill)).height, 64);
      final BoxDecoration decoration = _decorationOf(tester, StatPill);
      expect(decoration.color, BrandColors.surface);
      expect(decoration.borderRadius, BorderRadius.circular(22));
      expect(decoration.boxShadow!.single.offset, BrandShape.shadowButton);
    });

    testWidgets('the two differ only in height and fill',
        (WidgetTester tester) async {
      // The finding K8 rests on: compared to each other rather than each to the
      // default, the two agree on radius and shadow.
      await _pump(
        tester,
        const StatPill(
          size: StatPillSize.hero,
          height: 56,
          background: BrandColors.yellow,
          child: Text('7'),
        ),
      );
      final BoxDecoration badge = _decorationOf(tester, StatPill);

      await _pump(
        tester,
        const StatPill(
          size: StatPillSize.hero,
          height: 64,
          child: Text('1 180'),
        ),
      );
      final BoxDecoration chip = _decorationOf(tester, StatPill);

      expect(badge.borderRadius, chip.borderRadius);
      expect(badge.boxShadow!.single.offset, chip.boxShadow!.single.offset);
      expect(badge.color, isNot(chip.color));
    });
  });

  group('the counter chip', () {
    testWidgets('is outlined, unfilled and unshadowed',
        (WidgetTester tester) async {
      await _pump(tester, const OutlinedChip(label: '3 / 9'));

      final BoxDecoration decoration = _decorationOf(tester, OutlinedChip);
      expect(decoration.color, isNull);
      // Unset and empty both mean "no shadow"; the assertion is about the ink,
      // not about which of the two the decoration happens to use.
      expect(decoration.boxShadow ?? const <BoxShadow>[], isEmpty);
      expect(decoration.border!.top.width, BrandShape.borderWidthField);
      expect(find.text('3 / 9'), findsOneWidget);
    });
  });
}
