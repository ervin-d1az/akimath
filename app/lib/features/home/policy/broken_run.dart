/// The run that ended, and the day the next one is on.
///
/// **PURE** — the same `DayLog` days [streakLength] reads, and one moment. Two
/// small functions rather than one, because they answer two questions and only
/// one of them is arithmetic.
library;

/// The day number the run starting today is on.
///
/// **A separate quantity from `streakLength`, and the sharpest decision in this
/// feature.** `4.13 Racha perdida` draws `13 → 1` on a screen reached *before*
/// the player has solved anything, where `streakLength` correctly returns 0.
///
/// If the right-hand box read the streak, the screen would print `0` under a
/// headline saying *VOLVIÓ A UNO*. If `streakLength` were special-cased to say
/// `1` there, the home and this screen would disagree about what a streak
/// counts — one function, two answers, which is R2 wearing a different costume.
///
/// So they are two things. `streakLength` counts **days earned**. This names the
/// **day the new run is on**, which is `1` by definition and cannot drift,
/// because it is not derived from anything. *Empezar la de hoy* is the act that
/// makes it earned.
const int dayOfNewRun = 1;

/// How long the most recent run was.
///
/// Walks back from the newest recorded day rather than from [now]: the point of
/// the figure is the run that *ended*, and anchoring at today would report 0 for
/// every log whose last day is not yesterday — which is every log this is asked
/// about.
///
/// The two normalisations the rest of the streak arithmetic applies apply here:
/// a repeated day counts once, and a day after [now] is ignored rather than
/// trusted, because a device clock that jumped forward and back must not mint
/// one.
int brokenRunLength({
  required List<DateTime> attemptDays,
  required DateTime now,
}) {
  final DateTime today = _startOfDay(now);

  final Set<DateTime> played = <DateTime>{
    for (final DateTime attempt in attemptDays)
      if (!_startOfDay(attempt).isAfter(today)) _startOfDay(attempt),
  };
  if (played.isEmpty) {
    return 0;
  }

  DateTime cursor = played.reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);

  int length = 0;
  while (played.contains(cursor)) {
    length++;
    cursor = _previousDay(cursor);
  }
  return length;
}

/// The calendar day before [day], as local midnight.
///
/// Component arithmetic for the reason `streak_policy.dart` spells out at
/// length: a local day is 23, 24 or 25 hours long, so subtracting a `Duration`
/// misses the midnight this set is keyed by.
DateTime _previousDay(DateTime day) =>
    DateTime(day.year, day.month, day.day - 1);

DateTime _startOfDay(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
