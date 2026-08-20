import 'package:akimath_app/features/preferences/policy/erasure.dart';
import 'package:akimath_app/features/preferences/ui/erase_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    ErasureStep? step,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    VoidCallback? onRetry,
    VoidCallback? onDone,
  }) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EraseAccountScreen(
            step: step,
            onConfirm: onConfirm ?? () {},
            onCancel: onCancel ?? () {},
            onRetry: onRetry,
            onDone: onDone ?? () {},
          ),
        ),
      ));

  group('before anything is sent', () {
    testWidgets('it asks, and says what it is asking', (WidgetTester tester) async {
      await pump(tester);

      expect(find.text(erasureConfirmHeadline), findsOneWidget);
      expect(find.text(erasureConfirmDetail), findsOneWidget);
    });

    testWidgets('the way out is the prominent one', (WidgetTester tester) async {
      // A destructive act does not get the green button. Green is action and
      // success (BRD-1), and on this screen the action worth encouraging is
      // keeping your data — both choices are plainly labelled, and the safe one
      // is the one under your thumb.
      await pump(tester);

      final Finder keep = find.widgetWithText(GestureDetector, erasureConfirmNo);
      expect(keep, findsWidgets);
      expect(find.text(erasureConfirmYes), findsOneWidget);
    });

    testWidgets('and each button does its own thing', (WidgetTester tester) async {
      int confirmed = 0;
      int cancelled = 0;
      await pump(tester, onConfirm: () => confirmed++, onCancel: () => cancelled++);

      await tester.tap(find.text(erasureConfirmYes));
      await tester.pump();
      expect(<int>[confirmed, cancelled], <int>[1, 0]);

      await tester.tap(find.text(erasureConfirmNo));
      await tester.pump();
      expect(<int>[confirmed, cancelled], <int>[1, 1]);
    });

    testWidgets('nothing on it can be mistaken for the result', (WidgetTester tester) async {
      await pump(tester);

      for (final ErasureStep step in ErasureStep.values) {
        expect(find.text(erasureHeadline(step)), findsNothing, reason: step.name);
      }
    });
  });

  group('once it has been sent', () {
    testWidgets('every step draws its own words', (WidgetTester tester) async {
      for (final ErasureStep step in ErasureStep.values) {
        await pump(tester, step: step);

        expect(find.text(erasureHeadline(step)), findsOneWidget, reason: step.name);
        expect(find.text(erasureDetail(step)), findsOneWidget, reason: step.name);
        // The question is gone: it was asked and answered.
        expect(find.text(erasureConfirmYes), findsNothing, reason: step.name);
      }
    });

    testWidgets('a retry appears only where it could change the answer',
        (WidgetTester tester) async {
      for (final ErasureStep step in ErasureStep.values) {
        await pump(tester, step: step, onRetry: () {});

        expect(
          find.text('Reintentar'),
          canRetryErasure(step) ? findsOneWidget : findsNothing,
          reason: step.name,
        );
      }
    });

    testWidgets('and the way back appears once there is nothing left to wait for',
        (WidgetTester tester) async {
      await pump(tester, step: ErasureStep.erasing);
      expect(find.text('Volver'), findsNothing);

      await pump(tester, step: ErasureStep.gone);
      expect(find.text('Volver'), findsOneWidget);
    });

    testWidgets('leaving calls back exactly once', (WidgetTester tester) async {
      int done = 0;
      await pump(tester, step: ErasureStep.gone, onDone: () => done++);

      await tester.tap(find.text('Volver'));
      await tester.pump();

      expect(done, 1);
    });
  });
}
