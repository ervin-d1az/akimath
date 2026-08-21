import 'package:akimath_app/api/auth_result.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/account/policy/session_restore.dart';
import 'package:flutter_test/flutter_test.dart';

const StoredSession _stored = StoredSession(
  email: 'alguien@ejemplo.com',
  ageBand: AgeBand.thirteenToSeventeen,
  provider: AuthSession('better-auth.session_token=abc123'),
);

SessionRestore _answering(AuthResult<String> providerAnswer) =>
    sessionRestore(stored: _stored, providerAnswer: providerAnswer);

/// What a launch does with the credential it found on disk.
///
/// **The branch worth writing down is the third one.** The obvious reading —
/// *anything that is not a token means the credential is dead* — deletes a
/// perfectly good session because the player opened the app on a plane, and
/// then they are signed out with nothing on screen to say why.
void main() {
  group('a token means the session comes back', () {
    test('carrying the token that was just derived', () {
      final SessionRestore outcome =
          _answering(const AuthOk<String>('a.bearer.token'));

      expect(outcome, isA<SessionRestored>());
      expect((outcome as SessionRestored).session.accessToken, 'a.bearer.token');
    });

    test('and the address, the band and the credential that were stored', () {
      // **The band especially.** Linking needs it, it is not read off the
      // credential, and a restored session that had lost it could not link this
      // device at all. The credential travels too, or the next sign-out would
      // have nothing to delete.
      final SessionRestored outcome =
          _answering(const AuthOk<String>('t')) as SessionRestored;

      expect(outcome.session.email, 'alguien@ejemplo.com');
      expect(outcome.session.ageBand, AgeBand.thirteenToSeventeen);
      expect(outcome.session.provider, _stored.provider);
      expect(outcome.session.storable, _stored);
    });
  });

  test('a refusal is the one answer that deletes the credential', () {
    // `GET /token` with a cookie the provider no longer honours is a 401, which
    // `AuthClient` maps to `AuthRefused` — measured in `auth_client_test.dart`:
    // *'`GET /token` with no session is exactly the 401 that revealed the
    // endpoint'*. Asking again next launch gets the same refusal.
    expect(
      _answering(const AuthRefused<String>(
        status: 401,
        code: 'UNAUTHORIZED',
        message: 'Unauthorized',
      )),
      isA<SessionForgotten>(),
    );
  });

  test('nothing answered keeps it for the next launch', () {
    // The plane. Deleting here is the failure this union exists to prevent.
    expect(
      _answering(const AuthUnreachable<String>('no route to host')),
      isA<SessionKept>(),
    );
  });

  test('and an answer that could not be read keeps it too', () {
    // **This is the case a naive `is AuthOk ? restore : delete` gets wrong**,
    // and it is the mutation this test exists to kill. A 500, or a 200 whose
    // body carried no token, says nothing about whether the cookie is still
    // good — it says the provider is having a bad minute.
    expect(
      _answering(const AuthFailed<String>(status: 503, reason: 'gateway')),
      isA<SessionKept>(),
    );
    expect(
      _answering(const AuthFailed<String>(
        status: 200,
        reason: 'the token response carried no token',
      )),
      isA<SessionKept>(),
    );
  });

  test('every outcome is one some answer produces', () {
    // The four arms of `AuthResult` are sealed, so the switch inside is
    // exhaustive by compilation. This asserts the other direction: that no
    // outcome sits in the union looking handled while nothing returns it.
    expect(
      <Type>{
        _answering(const AuthOk<String>('t')).runtimeType,
        _answering(const AuthRefused<String>(status: 401, code: '', message: ''))
            .runtimeType,
        _answering(const AuthUnreachable<String>('')).runtimeType,
        _answering(const AuthFailed<String>(status: 500, reason: ''))
            .runtimeType,
      },
      <Type>{SessionRestored, SessionForgotten, SessionKept},
    );
  });
}
