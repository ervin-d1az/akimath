/// How far a player has got with a skill.
///
/// **A level, never a colour.** `BaselineMeter` takes one of these, so
/// "communicate progress by picking a hue at the call site" is not something a
/// caller can express — and `pct >= 90 ? green : pink` inside a `build()` would
/// pass the whole suite while breaking a stated invariant, which is why
/// `no_hue_by_comparison_test.dart` exists alongside this type.
///
/// **The four values are the skill map's own legend**, not an invention: the
/// plan records that `f5-skill-map`'s legend gains a fourth entry, *Disponible*,
/// and `4.14` is *Habilidad dominada*. Their producer arrives with that change;
/// meanwhile the adapter's mapping for **all four** is exercised, so no arm of
/// it is unreachable behind an enum a test merely pins.
///
/// The declaration order is least to most progress and is meaningful — a
/// comparison between two levels is the legitimate form of the comparison the
/// gate forbids on raw numbers.
library;

enum MasteryLevel {
  /// Not yet reachable: its prerequisites are unmet.
  locked,

  /// Reachable and untouched.
  available,

  /// Started, not finished.
  inProgress,

  /// Finished.
  mastered,
}
