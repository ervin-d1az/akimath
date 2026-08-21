import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:akimath_app/features/states/ui/account_state_view.dart';
import 'package:akimath_app/features/states/ui/server_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The account section as the profile mounts it, with a navigator over it so a
/// push has somewhere to go.
Future<void> pumpSection(
  WidgetTester tester, {
  required AccountState state,
  VoidCallback? onRetry,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AccountSection(
          child: AccountStateView(
            state: state,
            onRetry: onRetry,
            now: () => DateTime(2026, 8, 20, 18, 42),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // The scar this group exists for: five puzzle formats all rendered and four
  // were unreachable, with every suite green, because nothing asked "can a
  // player get there". These assert the path, not the pixels.
  group('reaching 4.10 from the account section', () {
    testWidgets('a server error offers a way into the full state', (
      WidgetTester tester,
    ) async {
      await pumpSection(
        tester,
        state: AccountState.serverError,
        onRetry: () {},
      );

      expect(find.text('Detalle'), findsOneWidget);

      await tester.tap(find.text('Detalle'));
      await tester.pumpAndSettle();

      expect(find.byType(ServerErrorScreen), findsOneWidget);
      expect(find.text('SOMOS NOSOTROS'), findsOneWidget);
    });

    testWidgets('the full state carries the retry the banner used to', (
      WidgetTester tester,
    ) async {
      int retried = 0;
      await pumpSection(
        tester,
        state: AccountState.serverError,
        onRetry: () => retried++,
      );

      await tester.tap(find.text('Detalle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Intentar de nuevo'));
      await tester.pumpAndSettle();

      expect(retried, 1);
      // And it closes behind itself: the answer to the retry is on the
      // profile, not on a stale error screen with no loading state of its own.
      expect(find.byType(ServerErrorScreen), findsNothing);
    });

    testWidgets('the note names when, since the state cannot name a code', (
      WidgetTester tester,
    ) async {
      await pumpSection(
        tester,
        state: AccountState.serverError,
        onRetry: () {},
      );

      await tester.tap(find.text('Detalle'));
      await tester.pumpAndSettle();

      expect(find.text('error · 18:42'), findsOneWidget);
    });

    // No retry means the full state would have no primary action, so there is
    // no door either — rather than a door onto a dead end.
    testWidgets('no retry, no door', (WidgetTester tester) async {
      await pumpSection(tester, state: AccountState.serverError);

      expect(find.text('Detalle'), findsNothing);
    });

    // Offline keeps the banner's own retry. `4.9` is about the pack in the
    // bag and the profile cannot count it — see the class comment.
    testWidgets('offline still retries in place', (WidgetTester tester) async {
      int retried = 0;
      await pumpSection(
        tester,
        state: AccountState.offline,
        onRetry: () => retried++,
      );

      expect(find.text('Detalle'), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();

      expect(retried, 1);
    });
  });
}
