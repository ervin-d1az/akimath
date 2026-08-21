import 'package:akimath_app/api/auth_result.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/account/data/session_store.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:akimath_app/features/shell/ui/root_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const StoredSession _stored = StoredSession(
  email: 'alguien@ejemplo.com',
  ageBand: AgeBand.thirteenToSeventeen,
  provider: AuthSession('better-auth.session_token=abc123'),
);

/// The shell, with both of its seams held.
///
/// **Neither may reach the real thing.** A `PrefsSessionStore` in a widget test
/// throws `MissingPluginException`, which the store's broad catch turns into
/// *no session* — the test would pass while proving nothing. A real
/// `AuthClient` inside a fake-async zone hangs on `!timersPending`.
Future<void> _pumpLaunch(
  WidgetTester tester, {
  required SessionStore sessions,
  required Future<AuthResult<String>> Function(AuthSession) deriveToken,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: RootScaffold(sessions: sessions, deriveToken: deriveToken),
  ));
}

ProfileRoute _profile(WidgetTester tester) =>
    tester.widget<ProfileRoute>(find.byType(ProfileRoute, skipOffstage: false));

Future<AuthResult<String>> Function(AuthSession) _answering(
  AuthResult<String> answer,
  List<AuthSession> asked,
) =>
    (AuthSession session) async {
      asked.add(session);
      return answer;
    };

void main() {
  group('a session survives a relaunch', () {
    testWidgets('a device that signed in last time comes up signed in',
        (WidgetTester tester) async {
      // **The two pumps are the test.** PROC-13: a value that flows from a
      // parent into a child is asserted on the *second* frame. The restore is a
      // `Future` created in `initState`, which is verbatim on that rule's list
      // of callbacks a data path dies in — and the session travels through
      // `TabStack`, which is the thing that froze its root and made signing in
      // change nothing on screen while 3,000 tests stayed green.
      final List<AuthSession> asked = <AuthSession>[];
      await _pumpLaunch(
        tester,
        sessions: InMemorySessionStore(_stored),
        deriveToken: _answering(const AuthOk<String>('nuevo.token'), asked),
      );

      expect(_profile(tester).session, isNull,
          reason: 'nothing has been read from storage yet');

      await tester.pumpAndSettle();

      expect(_profile(tester).session, isNotNull,
          reason: 'the restored session never reached the mounted root');
      expect(_profile(tester).session!.email, 'alguien@ejemplo.com');
    });

    testWidgets('with a token derived on launch, not the one it stored',
        (WidgetTester tester) async {
      // **The whole reason the cookie is what is persisted.** A Better Auth
      // access token is minted per request and expires in minutes; a device
      // that stored one would come up next launch and boot into a refusal.
      final List<AuthSession> asked = <AuthSession>[];
      await _pumpLaunch(
        tester,
        sessions: InMemorySessionStore(_stored),
        deriveToken: _answering(const AuthOk<String>('nuevo.token'), asked),
      );
      await tester.pumpAndSettle();

      expect(asked, <AuthSession>[_stored.provider],
          reason: 'the stored credential is what the provider was asked with');
      expect(_profile(tester).session!.accessToken, 'nuevo.token');
    });

    testWidgets('and both roots see it, which is why the shell holds it',
        (WidgetTester tester) async {
      // **The stated reason the session lives here at all.** One root signs in
      // and the other plays; `IndexedStack` keeps both alive, so a session held
      // inside either would never reach the other. A restore that only reached
      // the profile would leave the home playing the bundled pack for ever
      // while `Perfil` showed an address.
      final List<AuthSession> asked = <AuthSession>[];
      await _pumpLaunch(
        tester,
        sessions: InMemorySessionStore(_stored),
        deriveToken: _answering(const AuthOk<String>('nuevo.token'), asked),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<HomeRoute>(find.byType(HomeRoute, skipOffstage: false))
            .session
            ?.email,
        'alguien@ejemplo.com',
      );
    });

    testWidgets('and the band, because linking still needs it',
        (WidgetTester tester) async {
      // It is not read off the credential — linking is an adult's act and the
      // player need not be an adult — so a restored session that lost the band
      // could not link this device at all.
      final List<AuthSession> asked = <AuthSession>[];
      await _pumpLaunch(
        tester,
        sessions: InMemorySessionStore(_stored),
        deriveToken: _answering(const AuthOk<String>('nuevo.token'), asked),
      );
      await tester.pumpAndSettle();

      expect(_profile(tester).session!.ageBand, AgeBand.thirteenToSeventeen);
    });

    testWidgets('a device that never signed in asks the provider nothing',
        (WidgetTester tester) async {
      final List<AuthSession> asked = <AuthSession>[];
      await _pumpLaunch(
        tester,
        sessions: InMemorySessionStore(),
        deriveToken: _answering(const AuthOk<String>('nuevo.token'), asked),
      );
      await tester.pumpAndSettle();

      expect(asked, isEmpty);
      expect(_profile(tester).session, isNull);
    });
  });

  group('what a launch does when the credential does not work', () {
    testWidgets('a refused credential is deleted and not tried again',
        (WidgetTester tester) async {
      // The account is real and this device's credential is not. Keeping it
      // would ask again next launch and get the same refusal for ever.
      final InMemorySessionStore sessions = InMemorySessionStore(_stored);
      await _pumpLaunch(
        tester,
        sessions: sessions,
        deriveToken: _answering(
          const AuthRefused<String>(
              status: 401, code: 'UNAUTHORIZED', message: 'Unauthorized'),
          <AuthSession>[],
        ),
      );
      await tester.pumpAndSettle();

      expect(_profile(tester).session, isNull);
      expect(await sessions.read(), isNull, reason: 'a dead credential stayed');
    });

    testWidgets('and one the provider could not be reached about survives',
        (WidgetTester tester) async {
      // **The plane.** Signing a player out for having no signal, permanently,
      // is the failure the three-way split exists to prevent.
      final InMemorySessionStore sessions = InMemorySessionStore(_stored);
      await _pumpLaunch(
        tester,
        sessions: sessions,
        deriveToken: _answering(
          const AuthUnreachable<String>('no route to host'),
          <AuthSession>[],
        ),
      );
      await tester.pumpAndSettle();

      expect(_profile(tester).session, isNull,
          reason: 'there is no token, so there is no session this launch');
      expect(await sessions.read(), _stored,
          reason: 'the credential was thrown away over a bad minute');
    });
  });

  group('the store agrees with the session the shell holds', () {
    testWidgets('a session arriving with a credential is written down',
        (WidgetTester tester) async {
      final InMemorySessionStore sessions = InMemorySessionStore();
      await _pumpLaunch(
        tester,
        sessions: sessions,
        deriveToken: _answering(const AuthOk<String>('t'), <AuthSession>[]),
      );
      await tester.pumpAndSettle();

      // The shell's own hook, driven directly: `onSessionChanged` is how
      // `RootScaffold` learns of a sign-in, and it is the seam this change adds
      // behaviour to.
      _profile(tester).onSessionChanged!(const LinkedSession(
        email: 'alguien@ejemplo.com',
        accessToken: 'a.bearer.token',
        ageBand: AgeBand.thirteenToSeventeen,
        provider: AuthSession('better-auth.session_token=abc123'),
      ));
      await tester.pumpAndSettle();

      expect(await sessions.read(), _stored);
      expect(_profile(tester).session!.email, 'alguien@ejemplo.com');
    });

    testWidgets('signing out deletes it', (WidgetTester tester) async {
      // **The half the owner asked for.** A credential that outlived a manual
      // sign-out would sign the player back in on the next launch, which is the
      // opposite of what pressing `Cerrar sesión` means.
      final InMemorySessionStore sessions = InMemorySessionStore(_stored);
      await _pumpLaunch(
        tester,
        sessions: sessions,
        deriveToken: _answering(const AuthOk<String>('t'), <AuthSession>[]),
      );
      await tester.pumpAndSettle();
      expect(_profile(tester).session, isNotNull, reason: 'never signed in');

      _profile(tester).onSessionChanged!(null);
      await tester.pumpAndSettle();

      expect(await sessions.read(), isNull);
      expect(_profile(tester).session, isNull);
    });

    testWidgets('and a session arriving without one leaves nothing stale',
        (WidgetTester tester) async {
      // **Today this is every sign-in.** `auth_flow.dart` drops the cookie
      // before `LinkedAccount` is built, so the session the running app hands
      // over carries no credential. Keeping the previous one would mean the
      // next launch restoring an account the app is no longer signed in to —
      // possibly somebody else's.
      final InMemorySessionStore sessions = InMemorySessionStore(_stored);
      await _pumpLaunch(
        tester,
        sessions: sessions,
        deriveToken: _answering(const AuthOk<String>('t'), <AuthSession>[]),
      );
      await tester.pumpAndSettle();

      _profile(tester).onSessionChanged!(const LinkedSession(
        email: 'otra@ejemplo.com',
        accessToken: 'a.bearer.token',
        ageBand: AgeBand.adult,
      ));
      await tester.pumpAndSettle();

      expect(await sessions.read(), isNull);
      expect(_profile(tester).session!.email, 'otra@ejemplo.com');
    });
  });

  testWidgets('the shell it ships with reaches a real store', (
    WidgetTester tester,
  ) async {
    // **The seam must not have quietly replaced the app's behaviour.** A
    // default of `InMemorySessionStore` would make every test above pass and
    // the shipping app forget its session on every launch — which is the bug
    // this change exists to fix, reintroduced by the fix.
    expect(const RootScaffold().sessions, isA<PrefsSessionStore>());
    expect(const RootScaffold().deriveToken, isNull,
        reason: 'a null closure is what makes the shell open a real client');
  });
}

