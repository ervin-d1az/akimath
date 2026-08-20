import 'package:akimath_app/design/widgets/centered_state_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget child, {Size size = const Size(390, 844)}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(textDirection: TextDirection.ltr, child: child),
  );
}

void main() {
  group('the frame centres what fits and scrolls what does not', () {
    testWidgets('a short state sits in the middle, not at the top', (WidgetTester tester) async {
      // The design's body is `flex:1; justify-content:center`. Top-aligning it
      // leaves a state screen with a headline near the status bar and a hand's
      // depth of empty cream underneath — which is what a device showed.
      await pump(
        tester,
        CenteredStateView(headlineLines: const <String>['CORTA']),
      );

      final Rect headline = tester.getRect(find.text('CORTA'));
      final double middle = 844 / 2;
      expect(
        (headline.center.dy - middle).abs(),
        lessThan(60),
        reason: 'the headline is near the middle of the viewport',
      );
    });

    testWidgets('a tall state still scrolls rather than overflowing', (WidgetTester tester) async {
      await pump(
        tester,
        CenteredStateView(
          aki: true,
          headlineLines: const <String>['UNA', 'LÍNEA', 'POR', 'CADA', 'PALABRA'],
          body: 'Una oración larga que ocupa varias líneas en un teléfono estrecho '
              'y empuja todo lo demás hacia abajo sin remedio alguno.',
          content: const SizedBox(height: 400),
          primary: const SizedBox(height: 62),
          secondary: const SizedBox(height: 52),
        ),
      );

      expect(tester.takeException(), isNull);
      final ScrollableState scrollable = tester.state(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('the buttons stay at the bottom, not with the content', (WidgetTester tester) async {
      // The design's footer is `padding: 0 24px 30px` on the frame, not part of
      // the centred block: a way out that floated with the copy would land in
      // a different place on every state.
      await pump(
        tester,
        CenteredStateView(
          headlineLines: const <String>['CORTA'],
          primary: const Text('salir'),
        ),
      );

      final double button = tester.getRect(find.text('salir')).center.dy;
      expect(button, greaterThan(844 * 0.75));
    });
  });
}
