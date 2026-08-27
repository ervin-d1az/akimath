import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/states/data/streak_notice_store.dart';
import 'package:akimath_app/features/states/ui/streak_at_risk_screen.dart';
import 'package:akimath_app/features/states/ui/streak_lost_screen.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/device_state.dart';

/// The two streak screens on a real device, reached the way a player reaches
/// them: by what is on disk and what time it is.
///
/// **Seeded through the store, not by rooting `main.dart` at the screen.**
/// Rooting proves the widget renders, which the unit suite already proves. What
/// only a device can answer is whether the *shipped* pack, the *real*
/// `shared_preferences` and the real navigator get a player there — and whether
/// a 46px Darumadrop headline over Aki over a card over two buttons actually
/// fits a phone.
///
/// This was the one suite that already established its own state, and it was the
/// one suite that passed. `DeviceState.playedRunEnding` is that seeding lifted
/// into `support/`, where the other five could reach it — and where the run a
/// case wants is named at the top of the case rather than assembled from two
/// local closures.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a live run and a late hour lands on 4.12, and it leads back',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
    await establish(DeviceState.playedRunEnding(yesterday, length: 13));

    // The device's own hour is whatever it is, so the moment is handed in —
    // the same seam the unit tests use, and the reason `now` is a parameter.
    final DateTime evening = DateTime(now.year, now.month, now.day, 20, 14);

    await tester.pumpWidget(
      MaterialApp(
        theme: AkiMathTheme.build(),
        home: HomeRoute(now: () => evening),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StreakAtRiskScreen), findsOneWidget);
    expect(find.text('13'), findsOneWidget);

    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a broken run lands on 4.13, and the page turns once',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    await establish(
      DeviceState.playedRunEnding(
        DateTime(now.year, now.month, now.day - 3),
        length: 13,
      ),
    );

    Widget app() => MaterialApp(
          theme: AkiMathTheme.build(),
          home: HomeRoute(now: () => now),
        );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(StreakLostScreen), findsOneWidget);

    // **The caption, against a real seeded log on a real device.** The run
    // above ends three days before `now`, which is the only kind of log that
    // reaches this screen: `broken` needs the log to hold neither today nor
    // yesterday. `AYER` was drawn here for six days and was false every one of
    // them (LANG-2). Asserted at this level and not only in the widget test
    // because the day log is genuine here — seeded through the store the app
    // really reads, not handed to a constructor.
    expect(find.text('ANTES'), findsOneWidget);
    expect(find.text('HOY'), findsOneWidget);
    expect(find.text('AYER'), findsNothing);
    expect(find.text('13'), findsOneWidget);

    // The record is on disk now. A relaunch — a fresh widget over the same
    // preferences — must go straight to the home.
    expect(await const PrefsStreakNoticeStore().lostShownOn(), isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(StreakLostScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
