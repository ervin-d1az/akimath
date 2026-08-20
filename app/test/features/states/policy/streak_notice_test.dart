import 'package:akimath_app/features/home/policy/streak_state.dart';
import 'package:akimath_app/features/states/policy/streak_notice.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime day(int y, int m, int d) => DateTime(y, m, d);

void main() {
  final DateTime now = DateTime(2026, 8, 20, 20, 14);

  group('which notice the launch owes', () {
    test('a steady streak owes nothing', () {
      expect(
        streakNoticeFor(
          state: StreakState.steady,
          lostShownOn: null,
          now: now,
        ),
        StreakNotice.none,
      );
    });

    test('an empty log owes nothing', () {
      expect(
        streakNoticeFor(state: StreakState.none, lostShownOn: null, now: now),
        StreakNotice.none,
      );
    });

    test('a run at risk owes the warning', () {
      expect(
        streakNoticeFor(state: StreakState.atRisk, lostShownOn: null, now: now),
        StreakNotice.atRisk,
      );
    });

    test('the warning is owed again on the next launch of the same day', () {
      // **Not once a day.** The day is still at risk on the second launch, and
      // suppressing it would be the app deciding it had already said enough
      // about something that has not changed. Nothing records that the warning
      // was shown, which is what makes this true by construction.
      expect(
        streakNoticeFor(
          state: StreakState.atRisk,
          lostShownOn: day(2026, 8, 20),
          now: now,
        ),
        StreakNotice.atRisk,
        reason: "the lost notice's record says nothing about this one",
      );
    });

    test('a broken run owes the page turn', () {
      expect(
        streakNoticeFor(state: StreakState.broken, lostShownOn: null, now: now),
        StreakNotice.lost,
      );
    });

    test('the page turn is owed once a day and not twice', () {
      // Annotated *"se pasa la página"*, and a page turned twice is a page
      // that was not turned.
      expect(
        streakNoticeFor(
          state: StreakState.broken,
          lostShownOn: day(2026, 8, 20),
          now: now,
        ),
        StreakNotice.none,
      );
    });

    test('yesterday having seen it does not settle today', () {
      // A run broken on Monday is still broken on Tuesday, and Tuesday is a
      // new page.
      expect(
        streakNoticeFor(
          state: StreakState.broken,
          lostShownOn: day(2026, 8, 19),
          now: now,
        ),
        StreakNotice.lost,
      );
    });

    test('a record from the future does not suppress today', () {
      // A device clock that jumped forward and back must not silence a screen
      // for ever — the same normalisation the streak arithmetic applies.
      expect(
        streakNoticeFor(
          state: StreakState.broken,
          lostShownOn: day(2026, 9, 30),
          now: now,
        ),
        StreakNotice.lost,
      );
    });

    test('the time of day does not matter to the record, only the day', () {
      for (final int hour in <int>[0, 12, 23]) {
        expect(
          streakNoticeFor(
            state: StreakState.broken,
            lostShownOn: DateTime(2026, 8, 20, hour, 30),
            now: now,
          ),
          StreakNotice.none,
          reason: 'shown at $hour:30 is still shown today',
        );
      }
    });
  });
}
