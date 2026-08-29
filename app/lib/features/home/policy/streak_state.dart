/// What the streak is doing today, as one closed set.
///
/// **PURE** — a list of days and one moment in, a state out. No clock read, no
/// storage, no widget. `now` is a parameter for the same reason
/// [streakLength]'s `today` is: the whole policy is testable by handing it two
/// dates, and the alternative is a test that has to wait for an evening.
///
/// It exists because [streakLength] answers *how long*, and no caller has ever
/// been able to ask *is it about to go*. Those are different questions, and the
/// second one needs a time of day the first deliberately ignores.
library;

import '../../round/policy/streak_policy.dart';

/// The hour after which a day with nothing solved is worth mentioning.
///
/// **A product decision, and the only one in this file.** *Nothing solved
/// today* is equally true at 06:00 and means nothing there — the day has not
/// started. The design's own mock draws `4.12` at 20:14 and offers to remind
/// the player at 21:00, so the drawn instance is late evening.
///
/// Six in the afternoon. The screen asks for *"un reto de cuatro minutos"*, and
/// six hours of runway is generous for a four-minute ask while still being late
/// enough that the afternoon is plainly gone. Three would be a countdown that
/// arrives with the answer already decided.
///
/// Named here, with the reasoning, so moving it is a one-line diff and a test
/// that fails rather than a number hunted through a widget.
const int atRiskFrom = 18;

/// Where the streak stands.
enum StreakState {
  /// No day has ever been recorded. There is no run to lose.
  none,

  /// Either today is already in, or the day is young enough that nothing needs
  /// saying.
  steady,

  /// A live run, nothing today, and the day far enough gone that saying so is
  /// help rather than nagging. `Racha en riesgo`.
  atRisk,

  /// The run ended before yesterday. `Racha perdida`.
  broken,
}

/// The state the recorded days put the streak in at [now].
///
/// The two normalisations [streakLength] applies apply here too, because this
/// function *asks* it: a repeated day counts once, and a day after [now] is
/// ignored rather than trusted.
StreakState streakStateFor({
  required List<DateTime> attemptDays,
  required DateTime now,
}) {
  final DateTime today = _startOfDay(now);

  final Set<DateTime> played = <DateTime>{
    for (final DateTime attempt in attemptDays)
      if (!_startOfDay(attempt).isAfter(today)) _startOfDay(attempt),
  };
  if (played.isEmpty) {
    return StreakState.none;
  }

  if (played.contains(today)) {
    return StreakState.steady;
  }

  // **`streakLength`, not a second walk over the days.** It already knows that
  // yesterday keeps a run alive, and re-deciding that here is how the two
  // answers drift — the home saying one thing and this screen another, which is
  // the shape of the Tijuana defect that policy was rewritten to fix.
  final int live = streakLength(attemptDays: attemptDays, today: today);
  if (live == 0) {
    return StreakState.broken;
  }

  // A live run with nothing today. Whether that is worth a screen is the only
  // thing left, and it is a question about the hour.
  return now.hour >= atRiskFrom ? StreakState.atRisk : StreakState.steady;
}

/// How much of the local day is left at [now].
///
/// **Component arithmetic, never `add(const Duration(days: 1))`.** A `Duration`
/// is absolute elapsed time and a local calendar day is 23, 24 or 25 hours
/// long, so adding twenty-four hours to midnight lands at 23:00 or 01:00 across
/// a daylight-saving transition — and this figure would be an hour wrong on the
/// two days a year somebody would least believe it. `DateTime(y, m, d + 1)`
/// normalises across month and year ends and always yields the next calendar
/// day's local midnight, whatever the offset does.
///
/// Returns a `Duration` and not a sentence: formatting a number is
/// `EsMxNumber`'s job, and a test that reads a duration needs no es-MX spelling
/// in its assertion.
Duration hoursLeftToday(DateTime now) {
  final DateTime tomorrow = DateTime(now.year, now.month, now.day + 1);
  return tomorrow.difference(now);
}

DateTime _startOfDay(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
