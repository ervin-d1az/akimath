import 'dart:ui' as ui;

import 'package:akimath_app/design/painting/spec/dash_spec.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/candy_surface.dart';
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

    testWidgets('${screen.label} blurs nothing in a painter',
        (WidgetTester tester) async {
      // The four assertions above walk DecoratedBox and PhysicalModel, which is
      // every place a border could live *before* this change. A border drawn by
      // a CustomPainter is invisible to all of them — and CandySurface.borderDash
      // is exactly what moves one there, on the answer slot, the empty-state
      // placeholders, the locked map node, VerdictChip, every cage and Sopa's
      // capsule. Landing the dash without this would silently stop covering the
      // components that carry BRD-1's shape encoding (D22).
      await _pumpLarge(tester, screen.build());

      expect(
        find.byType(BackdropFilter),
        findsNothing,
        reason: 'BackdropFilter is a CLAUDE.md NEVER.',
      );

      for (final Paint paint in _paintsOf(tester)) {
        expect(
          paint.maskFilter,
          isNull,
          reason: 'A painter blurred in ${screen.label}.',
        );
      }
    });
  }

  group('the gate reaches into painters, not only decorations', () {
    testWidgets('it reports how many screens it walked', (WidgetTester tester) async {
      // A registry-driven gate that walks nothing looks exactly like a gate
      // that found nothing (PROC-8).
      expect(registeredScreens, isNotEmpty);
      // ignore: avoid_print
      print('  no blurred shadow · registered screens → ${registeredScreens.length}');
    });

    testWidgets('the DecoratedBox walk alone cannot see a painter blur',
        (WidgetTester tester) async {
      // This is the hole, kept as a permanent record rather than a claim in a
      // commit message. A dashed surface carries `border: null` in its
      // BoxDecoration and draws the outline in a painter, so the original four
      // assertions have nothing to inspect — they pass over a blur.
      await tester.pumpWidget(
        MaterialApp(
          theme: AkiMathTheme.build(),
          home: const Center(
            child: CandySurface(
              borderDash: DashSpec.locked,
              borderColor: BrandColors.pink,
              child: SizedBox(width: 96, height: 52),
            ),
          ),
        ),
      );

      final Iterable<DecoratedBox> boxes =
          tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      for (final DecoratedBox box in boxes) {
        final Decoration decoration = box.decoration;
        if (decoration is! BoxDecoration) {
          continue;
        }
        // Nothing to find: the dashed surface's border is not here.
        expect(decoration.border, isNull);
      }

      // And the new assertion is what does have something to inspect.
      expect(_paintsOf(tester), isNotEmpty,
          reason: 'the dashed outline should have reached a painter');
      for (final Paint paint in _paintsOf(tester)) {
        expect(paint.maskFilter, isNull);
      }
    });

    testWidgets('a painter that blurs is caught', (WidgetTester tester) async {
      // The same experiment with the opposite result. Without this the widened
      // assertion could be vacuous and nobody would know.
      await tester.pumpWidget(
        MaterialApp(
          theme: AkiMathTheme.build(),
          home: const Center(
            child: CustomPaint(
              foregroundPainter: _BlurringPainter(),
              child: SizedBox(width: 96, height: 52),
            ),
          ),
        ),
      );

      final List<Paint> paints = _paintsOf(tester);
      expect(paints, isNotEmpty);
      expect(
        paints.any((Paint p) => p.maskFilter != null),
        isTrue,
        reason: 'the spy failed to see a blur that is definitely there',
      );
    });
  });
}

/// Every `Paint` the pumped tree's painters use.
///
/// A painter's blur cannot be read off the widget tree — it only exists at the
/// moment of painting. So each painter is run against a canvas that records
/// nothing and reports every `Paint` it was handed.
List<Paint> _paintsOf(WidgetTester tester) {
  final List<Paint> paints = <Paint>[];
  for (final Element element in find.byType(CustomPaint).evaluate()) {
    final CustomPaint widget = element.widget as CustomPaint;
    final Size size = (element.renderObject! as RenderBox).size;
    for (final CustomPainter? painter in <CustomPainter?>[
      widget.painter,
      widget.foregroundPainter,
    ]) {
      if (painter == null) {
        continue;
      }
      final _PaintSpy spy = _PaintSpy();
      painter.paint(spy, size);
      paints.addAll(spy.paints);
    }
  }
  return paints;
}

/// A `Canvas` that draws nothing and keeps every `Paint` it is given.
///
/// `noSuchMethod` catches the whole draw surface rather than the handful of
/// calls in use today, so a painter added later cannot slip past by reaching
/// for a method this spy forgot to override.
class _PaintSpy implements Canvas {
  final List<Paint> paints = <Paint>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    for (final Object? argument in invocation.positionalArguments) {
      if (argument is Paint) {
        paints.add(argument);
      }
    }
    return null;
  }
}

class _BlurringPainter extends CustomPainter {
  const _BlurringPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = BrandColors.ink
        ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_BlurringPainter oldDelegate) => false;
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
