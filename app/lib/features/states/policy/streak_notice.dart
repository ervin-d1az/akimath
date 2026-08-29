/// Which streak screen a launch owes the player, if any.
///
/// **PURE** — a state, a recorded day and one moment in; one of three answers
/// out. No storage, no clock, no navigator.
///
/// Separate from `streakStateFor` because they answer different questions.
/// *Where the streak stands* is a fact about the calendar. *Whether to
/// interrupt* is a fact about the calendar **and** about what this app has
/// already said today, and folding the second into the first would make the
/// state depend on a preference.
library;

import '../../home/policy/streak_state.dart';

/// What to show before the home.
enum StreakNotice {
  /// The home, directly.
  none,

  /// `Racha en riesgo`.
  atRisk,

  /// `Racha perdida`.
  lost,
}

/// The notice due at [now].
///
/// **`atRisk` is owed on every launch of the day; `lost` is owed once.** Not a
/// symmetry anyone should tidy up: the day is still at risk on the second
/// launch and nothing about it has changed, so suppressing the warning would be
/// the app deciding it had already said enough. `4.13` is annotated *"se pasa
/// la página"*, and a page turned twice is a page that was not turned.
///
/// That asymmetry is why only one of the two is recorded at all. Nothing stores
/// that the warning was shown, which makes "shown again" true by construction
/// rather than by a branch somebody could invert.
///
/// [lostShownOn] is compared **by day**: the hour it was shown says nothing, and
/// a record dated after [now] is ignored rather than trusted — a device clock
/// that jumped forward and back must not silence a screen for ever.
StreakNotice streakNoticeFor({
  required StreakState state,
  required DateTime? lostShownOn,
  required DateTime now,
}) {
  switch (state) {
    case StreakState.none:
    case StreakState.steady:
      return StreakNotice.none;
    case StreakState.atRisk:
      return StreakNotice.atRisk;
    case StreakState.broken:
      final DateTime? shown = lostShownOn;
      if (shown == null) {
        return StreakNotice.lost;
      }
      final bool alreadyToday = _startOfDay(shown) == _startOfDay(now);
      return alreadyToday ? StreakNotice.none : StreakNotice.lost;
  }
}

DateTime _startOfDay(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
