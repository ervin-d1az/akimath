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

  group('a daylight-saving transition does not break a streak', () {
    // **These pass vacuously in a zone without DST**, which includes
    // `America/Mexico_City` (abolished 2022) and the UTC that CI defaults to.
    // `.github/workflows/ci.yml` therefore runs this file a second time under
    // `TZ=America/Tijuana`; without that run, the bug they cover is invisible
    // to the suite. Tijuana and Ciudad Juárez are Mexican DST zones, so this is
    // the target audience and not a travelling device.
    //
    // What it cost before the fix: a child with a 30-day run, opening the app
    // on the morning of 9 March 2026, saw **0** on the home and then **29** on
    // the verdict screen. Two screens, one morning, neither number right.
    List<DateTime> consecutiveDaysEnding(DateTime last, int count) => <DateTime>[
          for (int i = 0; i < count; i++)
            DateTime(last.year, last.month, last.day - i),
        ];

    test('the grace path survives spring forward', () {
      // Played through the 8th, opens the app on the 9th before playing.
      expect(
        streakLength(
          attemptDays: consecutiveDaysEnding(day(2026, 3, 8), 30),
          today: DateTime(2026, 3, 9, 9),
        ),
        30,
      );
    });

    test('the counting loop survives spring forward', () {
      // Played through the 9th, including today.
      expect(
        streakLength(
          attemptDays: consecutiveDaysEnding(day(2026, 3, 9), 30),
          today: DateTime(2026, 3, 9, 9),
        ),
        30,
      );
    });

    test('a run spanning autumn back is counted whole', () {
      expect(
        streakLength(
          attemptDays: consecutiveDaysEnding(day(2026, 11, 3), 10),
          today: DateTime(2026, 11, 3, 9),
        ),
        10,
      );
    });

    test('every day of a DST year counts a five-day run as five', () {
      // A sweep, because a single date proves one transition and there are two
      // a year in every zone that has them.
      for (int dayOfYear = 5; dayOfYear < 365; dayOfYear++) {
        final DateTime today = DateTime(2026, 1, dayOfYear);
        expect(
          streakLength(
            attemptDays: consecutiveDaysEnding(today, 5),
            today: today,
          ),
          5,
          reason: 'played-today path wrong at $today',
        );
        expect(
          streakLength(
            attemptDays: consecutiveDaysEnding(
              DateTime(today.year, today.month, today.day - 1),
              5,
            ),
            today: today,
          ),
          5,
          reason: 'grace path wrong at $today',
        );
      }
    });
  });
}
