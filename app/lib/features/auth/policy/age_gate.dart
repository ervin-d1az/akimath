import '../../../api/me.dart';

/// Where a resolved band sends the player.
///
/// Two destinations and no third: a band either reaches the account form or it
/// reaches the tutor-consent flow. `age_gate_test.dart` asserts the set, so a
/// third has to be added deliberately rather than appear.
enum AgeGateRoute { createAccount, tutorConsent }

/// The gate that stands in front of every door reaching the server.
///
/// **PURE** — no clock, no storage, no navigation. `today` is a parameter
/// because a gate that read the clock could not be tested across a birthday,
/// and the birthday is the whole difficulty.
///
/// `req-age-gate`: the band is resolved **before any session is obtained**, so
/// it is in hand before the first byte of player data leaves the phone.
/// `players.age_band` is NOT NULL, and `ADR 0002` removed guest sync, so
/// `1.2 Crear cuenta` is now the only door this stands in front of — the plan
/// named two because it predates that decision.
abstract final class AgeGate {
  /// The age at or above which a player may open an account unaided.
  ///
  /// **One constant, and its default is recorded rather than decided.** 13 is
  /// the COPPA-equivalent floor; whether Mexican civil law's *minor* makes 18
  /// the right number for LFPDPPP consent is Gate A's question. Naming it is
  /// what keeps that a one-line change instead of a redesign.
  static const int consentAge = 13;

  /// Where a band goes. Exhaustive over `AgeBand`, so a new band is a compile
  /// error here rather than a silent fall-through to the account form.
  static AgeGateRoute next(AgeBand band) => switch (band) {
    AgeBand.under13 => AgeGateRoute.tutorConsent,
    AgeBand.thirteenToSeventeen => AgeGateRoute.createAccount,
    AgeBand.adult => AgeGateRoute.createAccount,
  };

  /// The band a birth date falls into, and nothing else about the date.
  ///
  /// **The date is reduced here and discarded by the caller.** Nothing returned
  /// can carry a day, a month or a year: `AgeBand` has one field and it is a
  /// wire name. That is `req-age-gate`'s second scenario made structural rather
  /// than promised.
  ///
  /// Ages turn on the **birthday**, not on the year: subtracting years alone
  /// makes someone 13 up to 364 days early, which for this constant is the
  /// difference between an account form and a consent flow.
  static AgeBand bandFor({required DateTime bornOn, required DateTime today}) {
    final int years = _completedYears(bornOn: bornOn, today: today);
    if (years < 0) {
      throw ArgumentError.value(
        bornOn.toIso8601String(),
        'bornOn',
        'is after today, so it is a typo rather than a birth date',
      );
    }
    if (years < consentAge) {
      return AgeBand.under13;
    }
    return years < 18 ? AgeBand.thirteenToSeventeen : AgeBand.adult;
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
