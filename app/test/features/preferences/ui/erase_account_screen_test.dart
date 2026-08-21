import 'package:akimath_app/features/preferences/policy/erasure.dart';
import 'package:akimath_app/features/preferences/ui/erase_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TextEditingController typed;

  setUp(() => typed = TextEditingController());
  tearDown(() => typed.dispose());

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
            confirmWord: typed,
            onConfirm: onConfirm ?? () {},
            onCancel: onCancel ?? () {},
            onRetry: onRetry,
            onDone: onDone ?? () {},
          ),
        ),
      ));

  /// Types the word the way a player does, through the field.
  Future<void> write(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  group('before anything is sent', () {
    testWidgets('it asks, and says what it is asking', (WidgetTester tester) async {
      await pump(tester);

      expect(find.text(erasureConfirmHeadline), findsOneWidget);
      expect(find.text(erasureConfirmDetail), findsOneWidget);
    });

    testWidgets('and it asks for the word to be typed', (WidgetTester tester) async {
      await pump(tester);

      expect(find.text(erasureConfirmPrompt), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
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

    testWidgets('the destructive press does nothing until the word is there',
        (WidgetTester tester) async {
      // **The confirm is drawn and is not pressable.** A player has to be able
      // to see what the word buys them; what they must not be able to do is
      // reach it with the same gesture every other row in the app takes.
      int confirmed = 0;
      await pump(tester, onConfirm: () => confirmed++);

      expect(find.text(erasureConfirmYes), findsOneWidget);
      await tester.tap(find.text(erasureConfirmYes));
      await tester.pump();
      expect(confirmed, 0);

      await write(tester, 'BORRA');
      await tester.tap(find.text(erasureConfirmYes));
      await tester.pump();
      expect(confirmed, 0);
    });

    testWidgets('and each button does its own thing once it is', (WidgetTester tester) async {
      int confirmed = 0;
      int cancelled = 0;
      await pump(tester, onConfirm: () => confirmed++, onCancel: () => cancelled++);

      await write(tester, erasureConfirmWord);
      await tester.tap(find.text(erasureConfirmYes));
      await tester.pump();
      expect(<int>[confirmed, cancelled], <int>[1, 0]);

      await tester.tap(find.text(erasureConfirmNo));
      await tester.pump();
      expect(<int>[confirmed, cancelled], <int>[1, 1]);
    });

    testWidgets('the way out never needs the word', (WidgetTester tester) async {
      // The gate is on the act that loses data, not on the one that does not.
      int cancelled = 0;
      await pump(tester, onCancel: () => cancelled++);

      await tester.tap(find.text(erasureConfirmNo));
      await tester.pump();

      expect(cancelled, 1);
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

    testWidgets('the field is gone, because the question was answered',
        (WidgetTester tester) async {
      for (final ErasureStep step in ErasureStep.values) {
        await pump(tester, step: step);

        expect(find.byType(TextField), findsNothing, reason: step.name);
        expect(find.text(erasureConfirmPrompt), findsNothing, reason: step.name);
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
