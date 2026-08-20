import 'package:akimath_app/features/home/data/prefs_day_log_store.dart';
import 'package:akimath_app/features/home/policy/day_log.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/states/data/streak_notice_store.dart';
import 'package:akimath_app/features/states/ui/streak_at_risk_screen.dart';
import 'package:akimath_app/features/states/ui/streak_lost_screen.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two streak screens on a real device, reached the way a player reaches
/// them: by what is on disk and what time it is.
///
/// **Seeded through the store, not by rooting `main.dart` at the screen.**
/// Rooting proves the widget renders, which the unit suite already proves. What
/// only a device can answer is whether the *shipped* pack, the *real*
/// `shared_preferences` and the real navigator get a player there — and whether
/// a 46px Darumadrop headline over Aki over a card over two buttons actually
/// fits a phone.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seed(DayLog log) async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    await prefs.clear();
    await const PrefsDayLogStore().record(log.days.first);
    for (final DateTime day in log.days.skip(1)) {
      await const PrefsDayLogStore().record(day);
    }
  }

  DayLog runEnding(DateTime last, int length) {
    DayLog log = DayLog.empty;
    for (int back = length - 1; back >= 0; back--) {
      log = log.recording(DateTime(last.year, last.month, last.day - back));
    }
    return log;
  }

  testWidgets('a live run and a late hour lands on 4.12, and it leads back',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
    await seed(runEnding(yesterday, 13));

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
    await seed(runEnding(DateTime(now.year, now.month, now.day - 3), 13));

    Widget app() => MaterialApp(
          theme: AkiMathTheme.build(),
          home: HomeRoute(now: () => now),
        );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(StreakLostScreen), findsOneWidget);

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
