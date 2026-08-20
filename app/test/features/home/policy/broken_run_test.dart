import 'package:akimath_app/features/home/policy/broken_run.dart';
import 'package:akimath_app/features/round/policy/streak_policy.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime day(int y, int m, int d) => DateTime(y, m, d);

List<DateTime> run({required DateTime last, required int length}) =>
    <DateTime>[
      for (int back = length - 1; back >= 0; back--)
        DateTime(last.year, last.month, last.day - back),
    ];

void main() {
  group('the run that ended', () {
    test('thirteen days ending three days ago reads thirteen', () {
      expect(
        brokenRunLength(
          attemptDays: run(last: day(2026, 8, 17), length: 13),
          now: DateTime(2026, 8, 20, 8, 2),
        ),
        13,
      );
    });

    test('only the most recent run counts, not the longest', () {
      // A 30-day run in June and a 4-day run last week: the page being turned
      // is the second one.
      final List<DateTime> days = <DateTime>[
        ...run(last: day(2026, 6, 30), length: 30),
        ...run(last: day(2026, 8, 16), length: 4),
      ];

      expect(brokenRunLength(attemptDays: days, now: DateTime(2026, 8, 20)), 4);
    });

    test('an empty log has no run to report', () {
      expect(
        brokenRunLength(
          attemptDays: const <DateTime>[],
          now: DateTime(2026, 8, 20),
        ),
        0,
      );
    });

    test('a day after the moment is ignored, as everywhere else', () {
      expect(
        brokenRunLength(
          attemptDays: <DateTime>[day(2026, 8, 25)],
          now: DateTime(2026, 8, 20),
        ),
        0,
      );
    });

    test('a run still live reports itself, since it has not ended', () {
      // The screen that reads this is only reachable once the run is over, so
      // the live case is not a state anyone draws — but returning the live run
      // is the honest answer to "how long was the most recent run", and a
      // silent 0 here would be a figure invented to suit a caller.
      expect(
        brokenRunLength(
          attemptDays: run(last: day(2026, 8, 20), length: 5),
          now: DateTime(2026, 8, 20, 9),
        ),
        5,
      );
    });

    test('repeated days count once', () {
      expect(
        brokenRunLength(
          attemptDays: <DateTime>[
            day(2026, 8, 16),
            day(2026, 8, 16),
            day(2026, 8, 17),
          ],
          now: DateTime(2026, 8, 20),
        ),
        2,
      );
    });
  });

  group('the day the new run is on', () {
    test('is one, always', () {
      expect(dayOfNewRun, 1);
    });

    test('is not the streak, and the two disagree where the screen is drawn', () {
      // The whole reason it is a separate quantity (D3). `4.13` draws `13 → 1`
      // on a screen reached *before* the player has solved, where the streak is
      // correctly 0. One function answering both would be two callers
      // disagreeing about what it counts.
      final List<DateTime> days = run(last: day(2026, 8, 17), length: 13);

      expect(
        streakLength(attemptDays: days, today: DateTime(2026, 8, 20)),
        0,
        reason: 'nothing has been solved today',
      );
      expect(dayOfNewRun, 1, reason: 'the run that starts today is on day one');
    });
  });
}
