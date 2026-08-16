import 'package:akimath_app/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_registry.dart';

/// The visual system forbids blurred shadows, gradients, and backdrop filters.
///
/// That rule is only worth writing down if something enforces it, so this walks
/// the rendered tree of every screen and fails on the first blur. New screens
/// get added to [registeredScreens] and inherit the check — and the overflow
/// gate beside it — from that one registration.
void main() {
  for (final RegisteredScreen screen in registeredScreens) {
    testWidgets('${screen.label} draws only hard shadows', (WidgetTester tester) async {
      await _pumpLarge(tester, screen.build());

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
            reason: 'A blurred shadow appeared in ${screen.label}.',
          );
          expect(shadow.spreadRadius, 0);
        }
      }
    });

    testWidgets('${screen.label} raises nothing with Material elevation',
        (WidgetTester tester) async {
      await _pumpLarge(tester, screen.build());

      for (final PhysicalModel model in tester.widgetList<PhysicalModel>(find.byType(PhysicalModel))) {
        expect(model.elevation, 0, reason: 'Elevation blurs. Use CandySurface.');
      }
      for (final PhysicalShape shape in tester.widgetList<PhysicalShape>(find.byType(PhysicalShape))) {
        expect(shape.elevation, 0);
      }
    });
  }
}

/// The character sheet lays out full-width cards side by side, so it needs a
/// surface big enough to render without overflowing into an unrelated failure.
Future<void> _pumpLarge(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = const Size(2400, 4000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: AkiMathTheme.build(), home: screen),
  );
}
