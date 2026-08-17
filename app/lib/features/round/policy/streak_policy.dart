/// How many consecutive days the player has practised.
///
/// **A local calendar fact, not a server one** (D17). The streak survives with
/// no network because it is computed on the device from the days it recorded,
/// and it is one of only two figures a verdict screen shows in F2 — the other
/// being elapsed time. The rating is the server's exclusive authority and is
/// hidden entirely until F3, so nothing on an F2 verdict screen is a number
/// sync can later contradict.
///
/// Pure: two arguments in, an integer out. `today` is a parameter and never a
/// clock read, which is what lets the whole policy be tested by handing it two
/// dates.
library;

/// The number of consecutive calendar days ending at [today] or yesterday.
///
/// **Yesterday counts, and that is deliberate.** A streak that reset at
/// midnight would tell a child who opens the app before playing that they had
/// lost it. The day is not over until it is over.
///
/// **A wrong answer never decrements it** (Q7, decided 2026-08-15). This policy
/// is not given verdicts at all — it counts days practised, not days won, so it
/// has no way to punish one.
///
/// Attempts may arrive in any order and may repeat within a day; both are
/// normalised. An attempt dated after [today] is ignored rather than trusted: a
/// device clock that jumped forward and back should not mint days.
int streakLength({
  required List<DateTime> attemptDays,
  required DateTime today,
}) {
  final DateTime end = _startOfDay(today);

  final Set<DateTime> played = <DateTime>{
    for (final DateTime attempt in attemptDays)
      if (!_startOfDay(attempt).isAfter(end)) _startOfDay(attempt),
  };
  if (played.isEmpty) {
    return 0;
  }

  // The run may end today or yesterday; anything older is already broken.
  DateTime cursor = played.contains(end)
      ? end
      : end.subtract(const Duration(days: 1));
  if (!played.contains(cursor)) {
    return 0;
  }

  int length = 0;
  while (played.contains(cursor)) {
    length++;
    cursor = _startOfDay(cursor.subtract(const Duration(days: 1)));
  }
  return length;
}

/// Midnight local, so a time of day inside a counted day is ignored.
///
/// Q7 settles the boundary as the **device's local calendar day**. Constructing
/// a `DateTime` from year, month and day is exactly that, and it keeps this
/// module free of a timezone database — the `America/Mexico_City` fallback Q7
/// names is a question for a device that reports no zone, which is the
/// adapter's problem and not this function's.
DateTime _startOfDay(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
