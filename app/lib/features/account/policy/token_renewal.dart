/// Whether the access token in hand is still worth sending.
///
/// **PURE.** A mint time and an instant in, one of two answers out. No clock —
/// `now` is handed in, the same shape `streakLength` takes and for the same
/// reason: a function that read the clock could only be tested by waiting.
///
/// It exists because the app had no answer to the question at all. A token was
/// minted at launch or at sign-in and reused for the life of the process, and
/// a playthrough against the deployed server measured what that costs: a token
/// good for `POST /players/link` at 03:29:05 was refused for `POST /attempts`
/// at 03:49:30 — so **a player who plays for longer than the token lives stops
/// syncing until they restart the app**, with nothing on screen to say so
/// (`docs/qa/2026-09-02-first-production-playthrough.md` §2).
///
/// **Minting is the provider's job and this decides only when to ask again.**
/// Nothing here constructs, signs or refreshes a JWT — that is Neon Auth's, and
/// the credential a fresh token is derived from is the session cookie the
/// device already holds.
library;

/// What to do with the token in hand.
///
/// **A closed set of two, not a `bool`.** `renew == true` reads as *renew
/// succeeded* about as often as *renew is needed*, and the two are opposite;
/// the names below cannot be read either way. A sealed union would be the
/// shape if either answer carried something, and neither does — the token to
/// reuse is the one the caller already has, and the one to mint is the
/// provider's to produce.
enum TokenRenewal {
  /// Send the token already in hand.
  reuse,

  /// Ask the provider for a new one before sending anything.
  mint,
}

/// How long a token is worth reusing before a fresh one is asked for.
///
/// **This is not a claim about how long the provider's token lives.** Nobody
/// has measured that, and this deliberately does not guess it: it is how long
/// *this app* is willing to keep using one. What the playthrough established is
/// a ceiling — a token was accepted at zero and refused at twenty minutes and
/// twenty-five seconds — so any window at or above twenty minutes is known to
/// be too long, and everything below it is a margin whose size is a judgement.
///
/// Ten minutes leaves half the only interval anyone has observed as slack,
/// against a cost of roughly one extra `GET /token` per ten minutes of play.
/// The honest way to retire the guess is to read the token's own `exp` claim;
/// that needs `dart:convert` to decode the payload, which a pure root may not
/// import (`test/architecture/pure_boundary_test.dart` — an unlisted `dart:`
/// library fails closed), so it would live in an adapter and hand the instant
/// in here. Worth doing the day the window is measured to be wrong; the field
/// evidence says nothing against ten minutes today.
const Duration tokenReuseWindow = Duration(minutes: 10);

/// The decision.
///
/// [mintedAt] is when the token in hand came back from the provider and [now]
/// is the instant it is about to be used at. [reuseFor] is a parameter rather
/// than a read of [tokenReuseWindow] so a test drives the boundary instead of
/// restating the constant.
///
/// **Anything but a token aged forward inside the window is minted.** The
/// obvious case is a token that has had its allowance; the case worth naming is
/// a [mintedAt] in the *future*, which a device whose clock jumps backwards
/// produces — a timezone fix, a manual change, an NTP correction. Read as an
/// age, that is a negative number comfortably under any window, and the device
/// would hold one token for as long as the jump lasted. Being wrong towards
/// minting costs one request; being wrong the other way is the defect this
/// exists to fix.
TokenRenewal tokenRenewal({
  required DateTime mintedAt,
  required DateTime now,
  Duration reuseFor = tokenReuseWindow,
}) {
  final Duration age = now.difference(mintedAt);
  return !age.isNegative && age < reuseFor
      ? TokenRenewal.reuse
      : TokenRenewal.mint;
}
