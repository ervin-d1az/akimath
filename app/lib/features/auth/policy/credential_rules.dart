/// The rules an account form applies before anything reaches the network.
///
/// **PURE** — no clock, no storage, no HTTP. `remainingCooldown` takes two
/// timestamps precisely so it can be tested across a boundary without waiting
/// for one, which is `req-credential-rules`' whole point.
abstract final class CredentialRules {
  /// How long a player must wait before asking for another code.
  ///
  /// A minute, because the code arrives by email and email is not instant: a
  /// shorter window trains people to hammer the button while the first message
  /// is still in flight, and every press invalidates the code they are about to
  /// receive.
  static const Duration resendCooldown = Duration(seconds: 60);

  /// The shortest password the form will send.
  ///
  /// Better Auth's own floor is 8. Restating it here rather than discovering it
  /// from a 400 is what lets the form say so before the round trip.
  static const int minimumPasswordLength = 8;

  /// What is left of the cooldown, floored at zero.
  ///
  /// Never negative: a caller formatting the result should not have to check,
  /// and `-0:03` on a button is the kind of thing that ships.
  static Duration remainingCooldown(DateTime issuedAt, DateTime now) {
    final Duration elapsed = now.difference(issuedAt);
    final Duration left = resendCooldown - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether another code may be asked for yet.
  static bool canResend(DateTime issuedAt, DateTime now) =>
      remainingCooldown(issuedAt, now) == Duration.zero;

  /// A remaining cooldown as `m:ss`, which is how it is shown on the button.
  static String formatCooldown(Duration left) {
    final int seconds = left.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// Whether an address is worth sending, with no opinion beyond that.
  ///
  /// **Deliberately permissive.** The only address that matters is the one the
  /// code arrives at, and the provider is the authority on that. A client-side
  /// pattern that refuses a valid address is a player who cannot sign up and
  /// cannot find out why; one that accepts an invalid one costs a round trip.
  /// So this catches the typo classes a form can be sure about — no `@`, more
  /// than one, nothing either side, whitespace inside — and nothing else.
  static bool looksLikeEmail(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) {
      return false;
    }
    final List<String> parts = trimmed.split('@');
    if (parts.length != 2) {
      return false;
    }
    final String local = parts[0];
    final String domain = parts[1];
    return local.isNotEmpty && domain.contains('.') && !domain.startsWith('.') &&
        !domain.endsWith('.');
  }

  /// Whether a password is long enough to be worth sending.
  static bool longEnough(String password) =>
      password.length >= minimumPasswordLength;

  /// Whether a typed code is the shape the provider issues.
  static bool looksLikeCode(String value, {int digits = 6}) =>
      RegExp('^[0-9]{$digits}\$').hasMatch(value);
}
