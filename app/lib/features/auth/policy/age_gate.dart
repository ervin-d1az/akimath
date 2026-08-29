import '../../../api/me.dart';

/// What the gate answers about a resolved band.
///
/// **An answer and its opposite, not two destinations.** The gate used to route:
/// a band chose between child protections and none, so `under_13` reached a
/// tutor-consent flow and everything above it reached the account form. ADR 0004
/// makes the product adults-only, so there is nothing left to route *into* — the
/// consent flow was the entrance to machinery that will not be built. One band
/// is admitted and the rest are refused, and `age_gate_test.dart` asserts the
/// set so a third answer has to be added deliberately rather than appear.
enum AgeGateOutcome { createAccount, refused }

/// The gate that stands in front of every door reaching the server.
///
/// **PURE** — no clock, no storage, no navigation. `today` is a parameter
/// because a gate that read the clock could not be tested across a birthday,
/// and the birthday is the whole difficulty.
///
/// `req-no-account-without-a-declaration`: the band is resolved **before any
/// session is obtained**, so it is in hand before the first byte of player data
/// leaves the phone. `1.2 Crear cuenta` is the one door this stands in front of.
///
/// **This is a posture, not a barrier** (ADR 0004 §4). A self-declared date is
/// not verified by anything — no document, no payment instrument, no platform
/// signal — so somebody who wants an account and is fifteen types a different
/// year. What the gate is worth is that the question is asked, in a neutral form
/// that does not tell the player which answer opens the door, and that the
/// refusal happens before any account exists.
abstract final class AgeGate {
  /// The age at or above which a player may open an account.
  ///
  /// **One constant, and after ADR 0004 it means adulthood rather than
  /// consent.** It used to be 13 — the COPPA-equivalent floor for consenting
  /// unaided — and there is no consent to give any more, so the only number
  /// that still decides anything is the one that separates an adult from a
  /// minor.
  ///
  /// [next] does **not** read it: that switch is exhaustive over [AgeBand], so
  /// moving this number moves the reduction and cannot leave the two disagreeing.
  static const int adultAge = 18;

  /// Where `under_13` stops and `13_17` begins — a split the gate no longer
  /// acts on.
  ///
  /// **Kept because the vocabulary is kept.** ADR 0004 leaves the schema's
  /// `CHECK` and the frozen contract naming all three bands; they go dead by
  /// construction because nothing writes them once the gate refuses, rather than
  /// by being deleted. So a birth date still has to reduce to the right one of
  /// them, even though [next] answers both the same way.
  static const int teenBandAge = 13;

  /// Whether a band opens the account form. Exhaustive over [AgeBand], so a new
  /// band is a compile error here rather than a silent fall-through.
  static AgeGateOutcome next(AgeBand band) => switch (band) {
    AgeBand.under13 => AgeGateOutcome.refused,
    AgeBand.thirteenToSeventeen => AgeGateOutcome.refused,
    AgeBand.adult => AgeGateOutcome.createAccount,
  };

  /// The band a birth date falls into, and nothing else about the date.
  ///
  /// **The date is reduced here and discarded by the caller.** Nothing returned
  /// can carry a day, a month or a year: `AgeBand` has one field and it is a
  /// wire name. That is `req-no-account-without-a-declaration`'s second scenario
  /// made structural rather than promised.
  ///
  /// Ages turn on the **birthday**, not on the year: subtracting years alone
  /// makes someone 18 up to 364 days early, which for [adultAge] is the
  /// difference between an account form and a refusal.
  static AgeBand bandFor({required DateTime bornOn, required DateTime today}) {
    final int years = _completedYears(bornOn: bornOn, today: today);
    if (years < 0) {
      throw ArgumentError.value(
        bornOn.toIso8601String(),
        'bornOn',
        'is after today, so it is a typo rather than a birth date',
      );
    }
    if (years < teenBandAge) {
      return AgeBand.under13;
    }
    return years < adultAge ? AgeBand.thirteenToSeventeen : AgeBand.adult;
  }

  static int _completedYears({required DateTime bornOn, required DateTime today}) {
    int years = today.year - bornOn.year;
    // `DateTime.utc(2026, 2, 29)` rolls forward to 1 March on a common year,
    // which is exactly the behaviour wanted: a 29 February birthday counts on
    // the first day that exists after it.
    final DateTime birthdayThisYear =
        DateTime.utc(today.year, bornOn.month, bornOn.day);
    if (today.isBefore(birthdayThisYear)) {
      years -= 1;
    }
    return years;
  }
}
