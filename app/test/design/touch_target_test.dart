import 'package:akimath_app/design/theme.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_registry.dart';

/// Nothing you can press is smaller than a fingertip.
///
/// `BrandShape.minTouchTarget` has been a constant since the tokens landed and
/// nothing checked it. A number that is only ever read by the widgets that
/// already got it right is not an invariant — it is a comment with a type.
///
/// **48 logical pixels**, which is the floor both platforms publish and the one
/// `CLAUDE.md` names. The audience makes it matter more than usual: the product
/// is for adults *and* children can play, and a child's aim is worse than an
/// adult's, on a phone that is often a hand-me-down.
///
/// **Measured, not asserted about the widget.** A `SizedBox(48)` inside a
/// `Padding` inside a `Row` that ran out of room is 31 pixels wide on the
/// screen, and the constant says nothing about that. This pumps the real screen
/// at the real viewport and reads the rectangle the hit test would use.
const double _floor = BrandShape.minTouchTarget;

/// One thing a finger can hit, and how big it turned out to be.
@immutable
class Tappable {
  const Tappable({required this.what, required this.rect});

  final String what;
  final Rect rect;

  bool get fits => rect.width >= _floor - 0.01 && rect.height >= _floor - 0.01;

  @override
  String toString() =>
      '$what is ${rect.width.toStringAsFixed(1)}×${rect.height.toStringAsFixed(1)}';
}

/// Every tappable on the pumped tree, with the rectangle it occupies.
///
/// **`GestureDetector` and `InkWell`, by their callbacks.** Those are the two
/// this app builds presses out of; a detector with no `onTap` is a scroll or a
/// drag and is not something a finger has to land on precisely. Sweeping
/// `Semantics` instead would count every label.
List<Tappable> tappablesOn(WidgetTester tester) {
  final List<Tappable> found = <Tappable>[];

  void take(Finder finder, String what) {
    for (final Element element in finder.evaluate()) {
      final RenderObject? box = element.renderObject;
      if (box is! RenderBox || !box.hasSize) {
        continue;
      }
      final Offset topLeft = box.localToGlobal(Offset.zero);
      found.add(Tappable(what: what, rect: topLeft & box.size));
    }
  }

  take(
    find.byWidgetPredicate(
      (Widget w) => w is GestureDetector && w.onTap != null,
      description: 'a tappable GestureDetector',
    ),
    'a GestureDetector',
  );
  take(
    find.byWidgetPredicate(
      (Widget w) => w is InkWell && w.onTap != null,
      description: 'a tappable InkWell',
    ),
    'an InkWell',
  );
  return found;
}

Future<List<Tappable>> _pump(
  WidgetTester tester,
  Widget screen, {
  ScreenViewport viewport = ScreenViewport.designPhone,
}) async {
  tester.view
    ..physicalSize = viewport.physicalSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AkiMathTheme.build(),
      // Applied below `MaterialApp` for the reason `screen_overflow_test.dart`
      // records: `WidgetsApp` builds its own `MediaQuery` from the view, so a
      // wrapper above it is overridden and every screen silently passes at 1.0.
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(viewport.textScale)),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tappablesOn(tester);
}

void main() {
  group('the harness', () {
    testWidgets('finds a press and measures it', (WidgetTester tester) async {
      final List<Tappable> found = await _pump(
        tester,
        Center(
          child: GestureDetector(
            onTap: () {},
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      );

      expect(found, hasLength(1));
      expect(found.single.rect.size, const Size(60, 60));
      expect(found.single.fits, isTrue);
    });

    testWidgets('and would catch one that is too small', (WidgetTester tester) async {
      // The control. Without it the sweep below passes for a predicate that
      // matches nothing, which is how a gate looks green for a year.
      final List<Tappable> found = await _pump(
        tester,
        Center(
          child: GestureDetector(
            onTap: () {},
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      );

      expect(found.single.fits, isFalse);
      expect(found.single.toString(), contains('24.0×24.0'));
    });

    testWidgets('a detector nobody can tap is not counted', (WidgetTester tester) async {
      // A drag or a scroll is not something a finger has to land on precisely.
      final List<Tappable> found = await _pump(
        tester,
        Center(
          child: GestureDetector(
            onVerticalDragUpdate: (_) {},
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );

      expect(found, isEmpty);
    });
  });

  group('every registered screen', () {
    test('there are screens to walk', () {
      // PROC-10: an empty registry would make every case below vacuous.
      expect(registeredScreens, isNotEmpty);
    });

    testWidgets('and the sweep actually finds presses on them',
        (WidgetTester tester) async {
      // **The other half of PROC-10, and the one that matters here.** Every
      // per-screen case below passes for a screen with no tappables at all, so
      // a predicate that stopped matching — a widget swapped for `Listener`,
      // say — would turn the whole gate green and silent. This counts.
      int total = 0;
      final List<String> barren = <String>[];
      for (final RegisteredScreen screen in registeredScreens) {
        final int found = (await _pump(tester, screen.build())).length;
        total += found;
        if (found == 0) {
          barren.add(screen.label);
        }
      }

      expect(total, greaterThan(0));
      // Printed rather than asserted per screen: a screen with nothing to press
      // is legitimate — `04 Error` before its buttons, a loading state — and
      // pinning the list would make it churn on every new entry.
      // ignore: avoid_print
      debugPrint('  touch targets · ${registeredScreens.length} screens, '
          '$total press(es), ${barren.length} screen(s) with none');
    });

    for (final RegisteredScreen screen in registeredScreens) {
      // **Both viewports, and the second is the one worth having.** A press
      // that fits at 1.0 and is squeezed at 1.3 is the ordinary failure: the
      // label grows, the row runs out of room, and the button that gives way is
      // the one a child has to hit.
      for (final ScreenViewport viewport in screen.requiredViewports) {
        testWidgets(
            '${screen.label} · ${viewport.label}: nothing under ${_floor.toInt()}px',
            (WidgetTester tester) async {
          final List<Tappable> found =
              await _pump(tester, screen.build(), viewport: viewport);
          final List<Tappable> tooSmall =
              found.where((Tappable t) => !t.fits).toList();

          expect(
            tooSmall,
            isEmpty,
            reason: '${screen.label} has ${tooSmall.length} target(s) under '
                '${_floor.toInt()}px: ${tooSmall.join(", ")}',
          );
        });
      }
    }
  });
}
