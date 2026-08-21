/// Figures the product cannot compute yet, for the demo.
///
/// **PURE, and deliberately quarantined.** Every number here is invented. They
/// exist so the screens the design draws can be shown before the systems behind
/// them are built — rating is F4, and the device never learns whether an answer
/// was right, so accuracy and average time have no on-device source at all.
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
  static const int accuracyPercent = 78;

  /// `4.1` draws `6,8 s PROMEDIO`. Tenths of a second, so the screen formats it
  /// in es-MX with a decimal comma rather than carrying a `double` that a
  /// `toString` would print with a point.
  static const int averageTenthsOfSecond = 68;

  /// Whether the invented figures are drawn at all.
  ///
  /// **The one switch.** A build that flips this to false shows only what the
  /// product can prove, which is what shipping looks like.
  static const bool enabled = true;
}
