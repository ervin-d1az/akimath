import 'package:meta/meta.dart';

import '../../../api/me.dart';

/// The account this device is signed in to, while it is signed in.
///
/// **PURE, and in memory only.** Where a session may be written down is its own
/// decision with its own change — a token on disk is a credential on disk. Until
/// then it lives above the tab roots for the length of one run, which is what
/// lets two roots agree about whether there is an account at all.
///
/// **The address is here because a player has no name** (Q5). It is the only
/// thing the product can greet, and it is what `4.1` was always going to show.
@immutable
class LinkedSession {
  const LinkedSession({
    required this.email,
    required this.accessToken,
    required this.ageBand,
  });

  final String email;

  /// The band the age gate resolved before the account was made.
  ///
  /// **Carried, because linking needs it and only the gate knows it.**
  /// `players.age_band` is NOT NULL with no default and it is not read off the
  /// account: linking is an adult's act but the player need not be an adult,
  /// and taking `adult` off the credential would route a child out of their own
  /// protections — the one mistake the band exists to prevent.
  final AgeBand ageBand;

  /// The provider's JWT. Never rendered, never logged, never persisted.
  final String accessToken;

  @override
  bool operator ==(Object other) =>
      other is LinkedSession &&
      other.email == email &&
      other.accessToken == accessToken &&
      other.ageBand == ageBand;

  @override
  int get hashCode => Object.hash(email, accessToken, ageBand);

  /// **The token is not in it.** `toString` reaches logs, crash reports and the
  /// debugger's watch pane, and a credential that appears in any of those has
  /// left the device.
  @override
  String toString() => 'LinkedSession($email)';
}
