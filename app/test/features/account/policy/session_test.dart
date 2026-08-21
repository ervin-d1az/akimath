import 'package:akimath_app/api/auth_result.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const LinkedSession session = LinkedSession(
    email: 'alguien@ejemplo.com',
    accessToken: 'a.bearer.token',
    ageBand: AgeBand.adult,
  );

  test('it carries the address, because a player has no name', () {
    expect(session.email, 'alguien@ejemplo.com');
  });

  test('and its description does not carry the token', () {
    // `toString` reaches logs, crash reports and the debugger's watch pane. A
    // credential that appears in any of those has left the device.
    expect(session.toString(), contains('alguien@ejemplo.com'));
    expect(session.toString(), isNot(contains('a.bearer.token')));
  });

  test('nor the credential underneath it', () {
    // The provider's cookie outlives the token and is what survives a relaunch,
    // which makes it the more valuable of the two to leak.
    expect(
      const LinkedSession(
        email: 'alguien@ejemplo.com',
        accessToken: 'a.bearer.token',
        ageBand: AgeBand.adult,
        provider: AuthSession('better-auth.session_token=secreto'),
      ).toString(),
      isNot(contains('secreto')),
    );
  });

  test('two sessions for the same account and token are the same session', () {
    expect(
      session,
      const LinkedSession(email: 'alguien@ejemplo.com', accessToken: 'a.bearer.token', ageBand: AgeBand.adult),
    );
    expect(
      session.hashCode,
      const LinkedSession(email: 'alguien@ejemplo.com', accessToken: 'a.bearer.token', ageBand: AgeBand.adult).hashCode,
    );
    expect(
      session,
      isNot(const LinkedSession(email: 'alguien@ejemplo.com', accessToken: 'otro', ageBand: AgeBand.adult)),
    );
  });

  test('and two carrying different credentials are not', () {
    // **Built at runtime rather than `const`.** Dart canonicalises identical
    // `const` values, so an `==` that compared the credential by identity would
    // pass a `const` case and fail on the session a real sign-in builds — green
    // in the suite, wrong on a device.
    LinkedSession carrying(String cookie) => LinkedSession(
          email: 'alguien@ejemplo.com',
          accessToken: 'a.bearer.token',
          ageBand: AgeBand.adult,
          provider: AuthSession(String.fromCharCodes(cookie.codeUnits)),
        );

    expect(carrying('s=uno'), carrying('s=uno'));
    expect(carrying('s=uno').hashCode, carrying('s=uno').hashCode);
    expect(carrying('s=uno'), isNot(carrying('s=dos')));
    expect(carrying('s=uno'), isNot(session));
  });

  group('what is worth keeping between launches', () {
    test('a session carrying a credential can say what to store', () {
      final StoredSession? storable = const LinkedSession(
        email: 'alguien@ejemplo.com',
        accessToken: 'a.bearer.token',
        ageBand: AgeBand.thirteenToSeventeen,
        provider: AuthSession('s=abc'),
      ).storable;

      expect(storable, isNotNull);
      expect(storable!.email, 'alguien@ejemplo.com');
      expect(storable.ageBand, AgeBand.thirteenToSeventeen);
      expect(storable.provider, const AuthSession('s=abc'));
    });

    test('and one carrying none has nothing to store', () {
      // **Not a defect and not an error.** Today the credential is dropped
      // between `auth_flow.dart` and `profile_route.dart`, so every session the
      // running app builds arrives without one — and a store that wrote a row
      // with an empty cookie would come up next launch and ask the provider to
      // honour nothing.
      expect(session.storable, isNull);
    });

    test('a stored session becomes a live one when a token is derived', () {
      const StoredSession stored = StoredSession(
        email: 'alguien@ejemplo.com',
        ageBand: AgeBand.adult,
        provider: AuthSession('s=abc'),
      );

      expect(
        stored.linkedWith('a.bearer.token'),
        const LinkedSession(
          email: 'alguien@ejemplo.com',
          accessToken: 'a.bearer.token',
          ageBand: AgeBand.adult,
          provider: AuthSession('s=abc'),
        ),
      );
    });

    test('the round trip keeps the credential, so a sign-out can delete it', () {
      // The credential has to survive `LinkedSession → StoredSession →
      // LinkedSession`, or the second launch would come up signed in holding
      // nothing to store and the third would sign the player out again.
      const LinkedSession live = LinkedSession(
        email: 'alguien@ejemplo.com',
        accessToken: 'primero',
        ageBand: AgeBand.adult,
        provider: AuthSession('s=abc'),
      );

      expect(live.storable!.linkedWith('segundo').storable, live.storable);
    });

    test('and it is not in a stored session description either', () {
      expect(
        const StoredSession(
          email: 'alguien@ejemplo.com',
          ageBand: AgeBand.adult,
          provider: AuthSession('s=secreto'),
        ).toString(),
        isNot(contains('secreto')),
      );
    });
  });
}
