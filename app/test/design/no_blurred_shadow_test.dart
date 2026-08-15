import 'package:ambysmath_app/design/theme.dart';
import 'package:ambysmath_app/features/brand_gallery/brand_gallery_screen.dart';
import 'package:ambysmath_app/features/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The visual system forbids blurred shadows, gradients, and backdrop filters.
///
/// That rule is only worth writing down if something enforces it, so this walks
/// the rendered tree of every screen and fails on the first blur. New screens
/// get added to [_screens] and inherit the check.
void main() {
  final Map<String, Widget> screens = <String, Widget>{
    'brand gallery': const BrandGalleryScreen(),
    'splash · cream': const SplashScreen(),
    'splash · green': const SplashScreen(variant: SplashVariant.brandGreen),
  };

  for (final MapEntry<String, Widget> screen in screens.entries) {
    testWidgets('${screen.key} draws only hard shadows', (WidgetTester tester) async {
      await _pumpLarge(tester, screen.value);

      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      expect(boxes, isNotEmpty, reason: 'Nothing rendered — the check is vacuous.');

      for (final DecoratedBox box in boxes) {
        final Decoration decoration = box.decoration;
        if (decoration is! BoxDecoration) {
          continue;
        }

        expect(
          decoration.gradient,
          isNull,
          reason: 'Gradients are not part of the system.',
        );

        for (final BoxShadow shadow in decoration.boxShadow ?? const <BoxShadow>[]) {
          expect(
            shadow.blurRadius,
            0,
            reason: 'A blurred shadow appeared in ${screen.key}.',
          );
          expect(shadow.spreadRadius, 0);
        }
      }
    });

    testWidgets('${screen.key} raises nothing with Material elevation',
        (WidgetTester tester) async {
      await _pumpLarge(tester, screen.value);

      for (final PhysicalModel model in tester.widgetList<PhysicalModel>(find.byType(PhysicalModel))) {
        expect(model.elevation, 0, reason: 'Elevation blurs. Use CandySurface.');
      }
      for (final PhysicalShape shape in tester.widgetList<PhysicalShape>(find.byType(PhysicalShape))) {
        expect(shape.elevation, 0);
      }
    });
  }
}

/// The gallery lays out full phone frames side by side, so it needs a surface
/// big enough to render without overflowing into an unrelated failure.
Future<void> _pumpLarge(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = const Size(2400, 4000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: AmbysMathTheme.build(), home: screen),
  );
}
