import 'package:akimath_app/features/home/policy/streak_state.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime day(int y, int m, int d) => DateTime(y, m, d);

/// A run of [length] consecutive days ending on [last].
List<DateTime> run({required DateTime last, required int length}) =>
    <DateTime>[
      for (int back = length - 1; back >= 0; back--)
        DateTime(last.year, last.month, last.day - back),
    ];

void main() {
  group('what the streak is doing today', () {
    test('a run with today already recorded is steady', () {
      expect(
        streakStateFor(
          attemptDays: run(last: day(2026, 8, 20), length: 13),
          now: DateTime(2026, 8, 20, 20, 14),
        ),
        StreakState.steady,
      );
    });

    test('a live run with nothing today, late enough, is at risk', () {
      expect(
        streakStateFor(
          attemptDays: run(last: day(2026, 8, 19), length: 13),
          now: DateTime(2026, 8, 20, 20, 14),
        ),
        StreakState.atRisk,
      );
    });

    test('the same run early in the day is not yet at risk', () {
      // The day is not gone. Saying so before it is would be nagging.
      expect(
        streakStateFor(
          attemptDays: run(last: day(2026, 8, 19), length: 13),
          now: DateTime(2026, 8, 20, 7, 12),
        ),
        StreakState.steady,
      );
    });

    test('mid-afternoon is still not at risk', () {
      // **Brackets the constant rather than restating it.** A test asserting
      // `atRiskFrom == 18` would be killed only by itself. These two — 7:12 in
      // the morning and 15:00 in the afternoon against 20:14 in the evening —
      // pin the hour into a range a product decision can move inside without
      // anyone noticing, and cannot leave without a red build. A falsification
      // shifting 18 to 17 survives on purpose; shifting it to 15 or to 21 does
      // not.
      expect(
        streakStateFor(
          attemptDays: run(last: day(2026, 8, 19), length: 13),
          now: DateTime(2026, 8, 20, 15),
        ),
        StreakState.steady,
      );
    });

    test('the hour it turns is the one the policy names, not one before', () {
      final List<DateTime> days = run(last: day(2026, 8, 19), length: 3);

      expect(
        streakStateFor(
          attemptDays: days,
          now: DateTime(2026, 8, 20, atRiskFrom - 1, 59),
        ),
        StreakState.steady,
      );
      expect(
        streakStateFor(
          attemptDays: days,
          now: DateTime(2026, 8, 20, atRiskFrom),
        ),
        StreakState.atRisk,
      );
    });

    test('a run that ended before yesterday is broken', () {
      expect(
        streakStateFor(
          attemptDays: run(last: day(2026, 8, 17), length: 13),
          now: DateTime(2026, 8, 20, 8, 2),
        ),
        StreakState.broken,
      );
    });

    test('a broken run is broken all day, not only after the hour', () {
      final List<DateTime> days = run(last: day(2026, 8, 17), length: 13);

      for (final int hour in <int>[0, 7, atRiskFrom, 23]) {
        expect(
          streakStateFor(attemptDays: days, now: DateTime(2026, 8, 20, hour)),
          StreakState.broken,
          reason: 'at $hour:00 the run is already over',
        );
      }
    });

    test('an empty log is neither at risk nor lost', () {
      // There is no run to be at risk and none to have lost.
      expect(
        streakStateFor(
          attemptDays: const <DateTime>[],
          now: DateTime(2026, 8, 20, 20, 14),
        ),
        StreakState.none,
      );
    });

    test('a day recorded after the moment does not mint a run', () {
      // Same normalisation `streakLength` applies: a device clock that jumped
      // forward and back must not create a streak.
      expect(
        streakStateFor(
          attemptDays: <DateTime>[day(2026, 8, 25)],
          now: DateTime(2026, 8, 20, 20, 14),
        ),
        StreakState.none,
      );
    });

    test('a single day yesterday is a run of one, and it is at risk', () {
      expect(
        streakStateFor(
          attemptDays: <DateTime>[day(2026, 8, 19)],
          now: DateTime(2026, 8, 20, 20, 14),
        ),
        StreakState.atRisk,
      );
    });
  });

  group('the time left in the day', () {
    test('20:14 leaves three hours and forty-six minutes', () {
      // The design's own mock, and the figure its chip prints.
      expect(
        hoursLeftToday(DateTime(2026, 8, 20, 20, 14)),
        const Duration(hours: 3, minutes: 46),
      );
    });

    test('one minute before midnight leaves one minute', () {
      expect(
        hoursLeftToday(DateTime(2026, 8, 20, 23, 59)),
        const Duration(minutes: 1),
      );
    });

    test('midnight itself leaves the whole day', () {
      expect(
        hoursLeftToday(DateTime(2026, 8, 20)),
        const Duration(hours: 24),
      );
    });

    test('the figure is never negative', () {
      for (final int hour in <int>[0, 6, 12, 18, 23]) {
        expect(
          hoursLeftToday(DateTime(2026, 8, 20, hour, 30)).isNegative,
          isFalse,
        );
      }
    });

    test('seconds are carried, so the boundary is exact and not rounded', () {
      expect(
        hoursLeftToday(DateTime(2026, 8, 20, 23, 59, 30)),
        const Duration(seconds: 30),
      );
    });

    test('a short local day still ends at its own midnight', () {
      // Component arithmetic, never `add(Duration(days: 1))`: a local calendar
      // day is 23, 24 or 25 hours long, and adding 24 hours to midnight lands
      // an hour off across a daylight-saving transition. Whatever the host
      // zone does on this date, the answer ends at the *next calendar day's*
      // midnight — which is what this asserts without naming a zone.
      final DateTime noon = DateTime(2026, 3, 8, 12);
      final DateTime nextMidnight = DateTime(2026, 3, 9);

      expect(hoursLeftToday(noon), nextMidnight.difference(noon));
    });
  });

  group('the run 4.13 draws is never yesterday\'s', () {
    test('broken implies the newest recorded day is older than yesterday', () {
      // **The invariant behind a caption.** `Racha perdida` captions its
      // left counter, and the design's own caption is *AYER* — recorded in
      // `openspec/changes/archive/2026-08-20-f7-estados-de-racha/proposal.md`
      // as *"the design draws `AYER 13 → HOY 1`"*. It can never be true:
      // `broken` requires `streakLength == 0`, which requires the log to hold
      // neither today nor yesterday. So the run this screen reports on always
      // ended at least two days ago, and the drawn screen and the policy
      // disagree — the policy is right.
      //
      // A sweep rather than one example, because the claim is *never*, not
      // *usually*: an example would leave the caption true for some input
      // nobody enumerated.
      final DateTime now = DateTime(2026, 8, 26);
      final DateTime yesterday = DateTime(2026, 8, 25);

      int brokenCases = 0;
      for (int gap = 0; gap <= 30; gap++) {
        for (final int length in <int>[1, 2, 13, 90]) {
          for (final int hour in <int>[0, 9, 18, 23]) {
            final DateTime last =
                DateTime(now.year, now.month, now.day - gap);
            final List<DateTime> days = run(last: last, length: length);
            final DateTime moment =
                DateTime(now.year, now.month, now.day, hour);
            if (streakStateFor(attemptDays: days, now: moment) !=
                StreakState.broken) {
              continue;
            }
            brokenCases++;
            expect(
              last.isBefore(yesterday),
              isTrue,
              reason: 'gap $gap, length $length, hour $hour: the state is '
                  'broken, so the run it reports ended before yesterday',
            );
          }
        }
      }

      // PROC-10: a sweep that reached no broken case would assert nothing and
      // still pass. 29 gaps past yesterday, four lengths, four hours.
      expect(brokenCases, 464);
    });

    test('the gap where broken begins is two days, not one', () {
      // Brackets the boundary the caption turns on. At gap 1 the newest day is
      // yesterday and the run is still alive, so 4.13 is unreachable; at gap 2
      // it is broken and the run ended the day before yesterday. A change that
      // let `broken` fire on a yesterday log would make *AYER* true again —
      // and would fail here first.
      final DateTime now = DateTime(2026, 8, 26, 20);

      expect(
        streakStateFor(
          attemptDays: run(last: DateTime(2026, 8, 25), length: 13),
          now: now,
        ),
        StreakState.atRisk,
        reason: 'yesterday keeps the run alive',
      );
      expect(
        streakStateFor(
          attemptDays: run(last: DateTime(2026, 8, 24), length: 13),
          now: now,
        ),
        StreakState.broken,
      );
    });
  });
}
