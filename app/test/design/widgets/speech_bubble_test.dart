import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/speech_bubble.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// One drawing call, reduced to what this test cares about.
class _Op {
  const _Op(this.kind, this.style, this.color, [this.rect]);

  final String kind;
  final PaintingStyle style;
  final int color;
  final Rect? rect;

  @override
  String toString() => '$kind ${style.name}';
}

/// Records what a painter drew, in order.
class _Recorder implements Canvas {
  final List<_Op> ops = <_Op>[];

  @override
  void drawPath(Path path, Paint paint) =>
      ops.add(_Op('path', paint.style, paint.color.toARGB32()));

  @override
  void drawRect(Rect rect, Paint paint) =>
      ops.add(_Op('rect', paint.style, paint.color.toARGB32(), rect));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The tail's painter, taken off a pumped bubble so the test cannot drift from
/// what the widget actually builds.
Future<_Recorder> _paintTail(WidgetTester tester) async {
  await tester.pumpWidget(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SpeechBubble(text: 'hola')),
    ),
  );

  final CustomPaint paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(SpeechBubble),
      matching: find.byType(CustomPaint),
    ),
  );
  final _Recorder recorder = _Recorder();
  paint.painter!.paint(recorder, const Size(26, 18));
  return recorder;
}

void main() {
  group('the tail opens into the bubble', () {
    testWidgets('the seam is erased before anything is drawn over it',
        (WidgetTester tester) async {
      // A speech bubble's tail is not a triangle stuck underneath: its inside
      // is the bubble's inside. Drawn as a closed, fully stroked triangle it
      // reads as a separate little arrow hanging off the box — which is what
      // was reported.
      final _Recorder recorder = await _paintTail(tester);

      expect(recorder.ops.first.kind, 'rect',
          reason: 'the seam patch must come first, or it erases the tail');
      expect(recorder.ops.first.style, PaintingStyle.fill);
      expect(recorder.ops.first.color, BrandColors.surface.toARGB32());
    });

    testWidgets('the patch reaches past the bubble\'s whole border',
        (WidgetTester tester) async {
      // The design's own `h=4` was measured in the SVG's coordinate space and
      // does not cover a 3 px border once the box is scaled — and a patch that
      // removes most of a line leaves exactly the hairline that made the tail
      // look detached.
      final _Recorder recorder = await _paintTail(tester);
      final Rect patch = recorder.ops.first.rect!;

      expect(patch.top, lessThanOrEqualTo(-BrandShape.borderWidth));
    });

    testWidgets('it leaves the two side strokes alone',
        (WidgetTester tester) async {
      // Inset horizontally, or the patch eats the tops of the sides and the
      // outline stops meeting the bubble's.
      final _Recorder recorder = await _paintTail(tester);
      final Rect patch = recorder.ops.first.rect!;

      expect(patch.left, greaterThan(3));
      expect(patch.right, lessThan(23));
    });

    testWidgets('exactly one stroke, and it is the last thing drawn',
        (WidgetTester tester) async {
      final _Recorder recorder = await _paintTail(tester);
      final List<_Op> strokes = recorder.ops
          .where((_Op op) => op.style == PaintingStyle.stroke)
          .toList();

      expect(strokes, hasLength(1), reason: 'the top edge must not be stroked');
      expect(recorder.ops.last.style, PaintingStyle.stroke);
      expect(strokes.single.color, BrandColors.ink.toARGB32());
    });
  });

  group('it says what it was given', () {
    testWidgets('the text is drawn', (WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SpeechBubble(text: '¿Le entramos?')),
        ),
      );

      expect(find.text('¿Le entramos?'), findsOneWidget);
    });

    testWidgets('it leaves room below itself for the tail',
        (WidgetTester tester) async {
      // The tail hangs outside the bubble's box; without the padding it would
      // overlap whatever sits under it.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SpeechBubble(text: 'hola')),
        ),
      );

      final Size padded = tester.getSize(find.byType(SpeechBubble));
      final Size box = tester.getSize(find.descendant(
        of: find.byType(SpeechBubble),
        matching: find.byType(Container),
      ));

      expect(padded.height, greaterThan(box.height));
    });
  });
}
