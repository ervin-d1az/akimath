import 'package:akimath_app/features/round/policy/streak_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local calendar days, as the policy takes them.
DateTime day(int y, int m, int d) => DateTime(y, m, d);

void main() {
  group('a streak counts consecutive local calendar days', () {
    test('playing today after yesterday continues the streak', () {
      expect(
        streakLength(
          attemptDays: <DateTime>[day(2026, 8, 14), day(2026, 8, 15)],
          today: day(2026, 8, 15),
        ),
        2,
      );
    });

    test('a gap ends the streak at the run that reaches today', () {
      expect(
        streakLength(
          attemptDays: <DateTime>[
            day(2026, 8, 10),
            day(2026, 8, 11),
            // 12th and 13th missed.
            day(2026, 8, 14),
            day(2026, 8, 15),
          ],
          today: day(2026, 8, 15),
        ),
        2,
      );
    });

    test('having played yesterday but not today keeps the streak alive', () {
      // The day is not over. A streak that reset at midnight would punish a
      // child for opening the app in the morning.
      expect(
        streakLength(
          attemptDays: <DateTime>[day(2026, 8, 13), day(2026, 8, 14)],
          today: day(2026, 8, 15),
        ),
        2,
      );
    });

    test('a gap of two days is a broken streak', () {
      expect(
        streakLength(
          attemptDays: <DateTime>[day(2026, 8, 12), day(2026, 8, 13)],
          today: day(2026, 8, 15),
        ),
        0,
      );
    });

    test('no attempts is a streak of zero', () {
      expect(
        streakLength(attemptDays: <DateTime>[], today: day(2026, 8, 15)),
        0,
      );
    });

    test('playing twice in one day counts that day once', () {
      expect(
        streakLength(
          attemptDays: <DateTime>[
            day(2026, 8, 15),
            day(2026, 8, 15),
            day(2026, 8, 14),
          ],
          today: day(2026, 8, 15),
        ),
        2,
      );
    });

    test('the order attempts arrive in does not matter', () {
      expect(
        streakLength(
          attemptDays: <DateTime>[
            day(2026, 8, 15),
            day(2026, 8, 13),
            day(2026, 8, 14),
          ],
          today: day(2026, 8, 15),
        ),
        3,
      );
    });

    test('a time of day within a counted day is ignored', () {
      expect(
        streakLength(
          attemptDays: <DateTime>[
            DateTime(2026, 8, 14, 23, 59),
            DateTime(2026, 8, 15, 0, 1),
          ],
          today: DateTime(2026, 8, 15, 12),
        ),
        2,
      );
    });
  });

  group('what a streak never does', () {
    test('a wrong answer does not decrement it', () {
      // Q7, decided: the streak counts days played, not days won. The policy
      // never sees a verdict — which is how it cannot punish one.
      expect(
        streakLength(
          attemptDays: <DateTime>[day(2026, 8, 14), day(2026, 8, 15)],
          today: day(2026, 8, 15),
        ),
        2,
      );
    });

    test('it reads no clock of its own', () {
      // `today` is an argument. Two different todays over the same attempts
      // must disagree, which a module reaching for DateTime.now() cannot do.
      final List<DateTime> attempts = <DateTime>[
        day(2026, 8, 14),
        day(2026, 8, 15),
      ];
      expect(
        streakLength(attemptDays: attempts, today: day(2026, 8, 15)),
        isNot(streakLength(attemptDays: attempts, today: day(2026, 9, 30))),
      );
    });

    test('a future attempt does not extend the streak', () {
      // A device whose clock jumped forward and back should not mint days.
      expect(
        streakLength(
          attemptDays: <DateTime>[day(2026, 8, 15), day(2026, 12, 25)],
          today: day(2026, 8, 15),
        ),
        1,
      );
    });
  });
}
