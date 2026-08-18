import 'package:akimath_app/design/widgets/loading_dots.dart';
import 'package:akimath_app/features/shell/ui/skeleton_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  group('loading is skeletal, never a spinner', () {
    testWidgets('a skeleton occupies the box its content will occupy',
        (WidgetTester tester) async {
      // The point of a skeleton is that nothing jumps when the content lands.
      // A placeholder of a different size is a spinner with extra steps.
      await _pump(tester, const SkeletonBlock(width: 220, height: 52));
      expect(
        tester.getSize(find.byType(SkeletonBlock)),
        const Size(220, 52),
      );
    });

    testWidgets('a line skeleton matches the type size it stands in for',
        (WidgetTester tester) async {
      await _pump(tester, const SkeletonBlock.line(width: 180, fontSize: 15));
      expect(tester.getSize(find.byType(SkeletonBlock)), const Size(180, 15));
    });

    testWidgets('no spinner and no LoadingDots reach a loading state',
        (WidgetTester tester) async {
      await _pump(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SkeletonBlock(width: 220, height: 52),
            SizedBox(height: 12),
            SkeletonBlock.line(width: 180),
          ],
        ),
      );

      // `4.11` is annotated *esqueletos, sin ruedita*, and LoadingDots is
      // explicitly not to be repurposed for a product screen.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(LoadingDots), findsNothing);
    });

    testWidgets('a skeleton carries no motion', (WidgetTester tester) async {
      // A shimmer is motion and motion is F8. If one were added, pumping a
      // frame would change the tree.
      await _pump(tester, const SkeletonBlock(width: 220, height: 52));
      final Size before = tester.getSize(find.byType(SkeletonBlock));

      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.getSize(find.byType(SkeletonBlock)), before);
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'something is animating in a skeleton',
      );
    });
  });
}
