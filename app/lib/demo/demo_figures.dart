/// Figures the product cannot compute yet, for the demo.
///
/// **PURE, and deliberately quarantined.** Every number here is invented. They
/// exist so the screens the design draws can be shown before the systems behind
/// them are built — rating is F4, and no rating runs in Dart at all.
///
/// **One file, so deleting them is one commit and not a hunt.** Nothing here
/// may be read by a policy that decides anything; it is display-only, and the
/// day a real figure arrives its caller stops reading this and the constant
/// goes.
///
/// Values are taken from the design documents so the screens match what was
/// drawn, rather than from anyone's imagination.
abstract final class DemoFigures {
  /// `4.1` draws `1 248`.
  static const int rating = 1248;

  /// `4.1` draws `+ 36 esta semana`.
  static const int ratingThisWeek = 36;

  /// `4.1` draws `312 RETOS`.
  static const int challenges = 312;

  /// `4.1` draws `78% ACIERTOS`, as a whole percent.
  ///
  /// **Superseded — there is a real source now.** The belief that put this here
  /// was that the device has none, and it was wrong:
  /// `features/round/policy/grading.dart` decides every verdict locally, which
  /// is how a wrong answer draws `04 Error` with no network. What the device
  /// does not do is *send* it. `features/stats/` remembers it instead, and
  /// `LocalStats.accuracyPercent` is the same figure computed from what the
  /// player actually did — **absent rather than `0` over no answers**, which is
  /// the one thing a constant cannot be. This goes when `4.1` is wired to it.
  static const int accuracyPercent = 78;

  /// `4.1` draws `6,8 s PROMEDIO`. Tenths of a second, so the screen formats it
  /// in es-MX with a decimal comma rather than carrying a `double` that a
  /// `toString` would print with a point.
  ///
  /// **Superseded by `LocalStats.meanTime`, and that is the only source there
  /// will be.** Time on task has no wire representation in either direction:
  /// the frozen `Standing` is `{playerId, skills: […]}` with
  /// `additionalProperties: false` and `GET /me/history` carries a score and no
  /// timing, so no endpoint can ever answer this. The device measures it or
  /// nobody does.
  static const int averageTenthsOfSecond = 68;

  /// Whether the invented figures are drawn at all.
  ///
  /// **The one switch.** A build that flips this to false shows only what the
  /// product can prove, which is what shipping looks like.
  static const bool enabled = true;
}
