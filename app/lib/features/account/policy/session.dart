import 'package:meta/meta.dart';

import '../../../api/auth_result.dart';
import '../../../api/me.dart';

/// The account this device is signed in to, while it is signed in.
///
/// **PURE.** No socket, no storage: what is *worth* writing down is [storable],
/// and the writing itself is `data/session_store.dart`.
///
/// It lives above the tab roots, which is what lets two roots agree about
/// whether there is an account at all.
///
/// **The address is here because a player has no name** (Q5). It is the only
/// thing the product can greet, and it is what `4.1` was always going to show.
@immutable
class LinkedSession {
  const LinkedSession({
    required this.email,
    required this.accessToken,
    required this.ageBand,
    this.provider,
  });

  final String email;

  /// The band the age gate resolved before the account was made, or the one
  /// `GET /me` reported for an account that already had a player.
  ///
  /// **Carried, because linking needs it and the credential does not hold it.**
  /// `players.age_band` is NOT NULL with no default, and taking `adult` off the
  /// credential would be the app asserting an age nobody declared — the one
  /// mistake the field exists to prevent.
  ///
  /// **After ADR 0004 a session this build creates can only hold `adult`**, on
  /// both paths: `AuthFlow` puts every band through `AgeGate.next` and ends the
  /// flow rather than building a session for anything below adulthood. The type
  /// still admits three because the frozen contract and the `CHECK` still name
  /// three — they go dead by construction rather than by being narrowed — and
  /// because a `13_17` value can still arrive from `data/session_store.dart` on
  /// a device that linked before this change.
  final AgeBand ageBand;

  /// The provider's JWT. Never rendered, never logged, never persisted.
  ///
  /// **It is the short-lived half and it is not what survives a relaunch.** A
  /// Better Auth access token is minted per request from [provider] and expires
  /// in minutes; a device that wrote this down would come up next launch and
  /// boot straight into a refusal.
  final String accessToken;

  /// The provider credential [accessToken] was derived from, where the device
  /// has it.
  ///
  /// **Nullable, because today it does not arrive.** `auth_flow.dart` holds the
  /// `AuthSession` long enough to call `accessToken(session)` and then drops
  /// it — `LinkedAccount` carries the token, the band and the address and not
  /// the cookie — so every session the running app builds has none of this and
  /// nothing is stored. The two one-line edits that change that are named in
  /// this change's report; until they land, persistence is code that is right
  /// and unreached, which is a better state than persistence that is wrong.
  final AuthSession? provider;

  /// What is worth keeping between launches, or null when there is nothing.
  ///
  /// **The token is deliberately not in it.** That is the whole reason
  /// [StoredSession] is a type of its own rather than this one with a field
  /// blanked: a shape that cannot hold a JWT cannot accidentally persist one,
  /// the same construction as the server's `NoContent` being separate from
  /// `Response`.
  StoredSession? get storable => provider == null
      ? null
      : StoredSession(email: email, ageBand: ageBand, provider: provider!);

  @override
  bool operator ==(Object other) =>
      other is LinkedSession &&
      other.email == email &&
      other.accessToken == accessToken &&
      other.ageBand == ageBand &&
      other.provider == provider;

  @override
  int get hashCode => Object.hash(email, accessToken, ageBand, provider);

  /// **Neither credential is in it.** `toString` reaches logs, crash reports
  /// and the debugger's watch pane, and a credential that appears in any of
  /// those has left the device. `AuthSession` redacts itself for the same
  /// reason, so this holds even where one is interpolated.
  @override
  String toString() => 'LinkedSession($email)';
}

/// What survives a relaunch.
///
/// **PURE, and a type rather than a convention.** The durable credential is the
/// provider's session cookie and not the access token derived from it: Better
/// Auth mints a JWT per request and it expires in minutes, so a device that
/// stored one would come up signed in for as long as it took the server to
/// refuse it. Storing the cookie and asking for a token on launch is the only
/// arrangement where *being signed in* survives the app being killed.
///
/// **The band is here because linking still needs it and the credential does
/// not carry it.** Per ADR 0002 a device that the gate refuses never obtains a
/// session at all, and after ADR 0004 the gate refuses every band below
/// adulthood — so a value **this build** writes here can only ever be `adult`.
///
/// **Read is not the same as written, and that is the whole reason this note
/// exists.** Until ADR 0004, `13_17` reached the account form, linked and was
/// stored; `shared_preferences` survives an upgrade, so a device that ran an
/// older build can hand one back on the next launch. `AgeBand.fromWire` still
/// parses all three deliberately: refusing a value the frozen contract names
/// would turn a real device's stored session into a `FormatException` on
/// launch, which is a worse answer than reading it. What happens to such a
/// session after it is read is an open question ADR 0004 §Open does not settle
/// — today it is restored and linked, because the eligibility gate lives in
/// `AuthFlow` and a relaunch does not pass through it.
@immutable
class StoredSession {
  const StoredSession({
    required this.email,
    required this.ageBand,
    required this.provider,
  });

  final String email;
  final AgeBand ageBand;

  /// The provider's session cookie — the credential, and the reason this is
  /// worth protecting.
  final AuthSession provider;

  /// The live session this becomes once a token has been derived from it.
  LinkedSession linkedWith(String accessToken) => LinkedSession(
        email: email,
        accessToken: accessToken,
        ageBand: ageBand,
        provider: provider,
      );

  @override
  bool operator ==(Object other) =>
      other is StoredSession &&
      other.email == email &&
      other.ageBand == ageBand &&
      other.provider == provider;

  @override
  int get hashCode => Object.hash(email, ageBand, provider);

  @override
  String toString() => 'StoredSession($email)';
}
