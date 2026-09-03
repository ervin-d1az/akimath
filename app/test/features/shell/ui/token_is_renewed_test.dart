import 'package:akimath_app/api/auth_result.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/account/data/session_store.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/account/policy/token_renewal.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:akimath_app/features/shell/ui/root_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The credential on disk. The cookie is what survives; the token is derived.
const StoredSession _stored = StoredSession(
  email: 'alguien@ejemplo.com',
  ageBand: AgeBand.adult,
  provider: AuthSession('better-auth.session_token=abc123'),
);

/// A clock the test moves by hand.
///
/// **Two clocks have to move together and they are not the same clock.**
/// `tester.pump(d)` advances the fake-async clock the shell's timer is
/// scheduled against; this one is what the shell *reads* to date the token it
/// holds. Advancing only the first fires a check that sees no time pass.
class _Clock {
  _Clock(this._at);

  DateTime _at;

  DateTime read() => _at;

  /// Moves both clocks: this one, and the tester's, so the check fires.
  Future<void> advance(WidgetTester tester, Duration by) async {
    _at = _at.add(by);
    await tester.pump(by);
    await tester.pumpAndSettle();
  }
}

/// A provider that hands out a differently spelled token every time it is asked.
class _Provider {
  final List<AuthSession> asked = <AuthSession>[];

  /// What the next call answers. Replaced to drive the failure branches.
  AuthResult<String>? refuseWith;

  Future<AuthResult<String>> call(AuthSession session) async {
    asked.add(session);
    return refuseWith ?? AuthOk<String>('token.${asked.length}');
  }
}

ProfileRoute _profile(WidgetTester tester) =>
    tester.widget<ProfileRoute>(find.byType(ProfileRoute, skipOffstage: false));

HomeRoute _home(WidgetTester tester) =>
    tester.widget<HomeRoute>(find.byType(HomeRoute, skipOffstage: false));

Future<void> _pump(
  WidgetTester tester, {
  required SessionStore sessions,
  required _Provider provider,
  required _Clock clock,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: RootScaffold(
      sessions: sessions,
      deriveToken: provider.call,
      now: clock.read,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  late _Clock clock;
  late _Provider provider;
  late InMemorySessionStore sessions;

  setUp(() {
    clock = _Clock(DateTime.utc(2026, 9, 2, 3, 29, 5));
    provider = _Provider();
    sessions = InMemorySessionStore(_stored);
  });

  group('a token does not outlive its window inside one process', () {
    testWidgets('a session held past the window is given a fresh token',
        (WidgetTester tester) async {
      // **The defect, measured.** `POST /players/link` at 03:29:05 answered
      // 200 and `POST /attempts` at 03:49:30 answered 401 on the same token —
      // so a player who plays for longer than the token lives stops syncing
      // until they relaunch, with nothing on screen to say so.
      // `docs/qa/2026-09-02-first-production-playthrough.md` §2.
      await _pump(
          tester, sessions: sessions, provider: provider, clock: clock);

      expect(_profile(tester).session!.accessToken, 'token.1');
      expect(provider.asked.length, 1, reason: 'the launch mint');

      await clock.advance(tester, tokenReuseWindow + const Duration(minutes: 1));

      expect(provider.asked.length, 2,
          reason: 'the token was never renewed inside the process');
      expect(_profile(tester).session!.accessToken, 'token.2');
    });

    testWidgets('and the credential it is minted from is the stored one',
        (WidgetTester tester) async {
      // Minting is the provider's job and this only calls it again — the
      // cookie on disk is the same one the launch used, and nothing here
      // constructs, signs or refreshes a JWT.
      await _pump(
          tester, sessions: sessions, provider: provider, clock: clock);
      await clock.advance(tester, tokenReuseWindow + const Duration(minutes: 1));

      expect(provider.asked, <AuthSession>[_stored.provider, _stored.provider]);
    });

    testWidgets('the fresh token reaches every root, not only the shell',
        (WidgetTester tester) async {
      // The whole point: the home is what flushes the attempt journal, so a
      // renewal the home never sees fixes nothing.
      await _pump(
          tester, sessions: sessions, provider: provider, clock: clock);
      await clock.advance(tester, tokenReuseWindow + const Duration(minutes: 1));

      expect(_home(tester).session!.accessToken, 'token.2');
      expect(_profile(tester).session!.accessToken, 'token.2');
    });

    testWidgets('a token still inside its window is left alone',
        (WidgetTester tester) async {
      // A renewal is not free — every root reacts to a token it has not seen
      // before — so it happens when the token is spent and not on a schedule.
      await _pump(
          tester, sessions: sessions, provider: provider, clock: clock);

      await clock.advance(tester, tokenReuseWindow - const Duration(minutes: 1));

      expect(provider.asked.length, 1);
      expect(_profile(tester).session!.accessToken, 'token.1');
    });

    testWidgets('a device with no session asks the provider nothing',
        (WidgetTester tester) async {
      await _pump(
        tester,
        sessions: InMemorySessionStore(),
        provider: provider,
        clock: clock,
      );

      await clock.advance(tester, tokenReuseWindow * 3);

      expect(provider.asked, isEmpty);
    });
  });

  group('when the renewal does not come back with a token', () {
    testWidgets('a refusal signs the device out and deletes the credential',
        (WidgetTester tester) async {
      // The same three-way reading `sessionRestore` already makes at launch,
      // reused rather than re-decided: refused means the provider has disowned
      // this credential, and asking again gets the same answer for ever.
      await _pump(
          tester, sessions: sessions, provider: provider, clock: clock);

      provider.refuseWith = const AuthRefused<String>(
          status: 401, code: 'UNAUTHORIZED', message: 'Unauthorized');
      await clock.advance(tester, tokenReuseWindow + const Duration(minutes: 1));

      expect(_profile(tester).session, isNull,
          reason: 'the shell kept holding a session the provider disowned');
      expect(await sessions.read(), isNull,
          reason: 'a dead credential stayed on disk');
    });

    testWidgets('and being unreachable changes nothing at all',
        (WidgetTester tester) async {
      // **The plane, mid-process.** Nothing was asked, so nothing was learned:
      // signing a player out here would be the failure the split exists to
      // prevent, one launch later than where it was first prevented.
      await _pump(
          tester, sessions: sessions, provider: provider, clock: clock);

      provider.refuseWith = const AuthUnreachable<String>('no route to host');
      await clock.advance(tester, tokenReuseWindow + const Duration(minutes: 1));

      expect(_profile(tester).session!.accessToken, 'token.1',
          reason: 'the session in hand was dropped over a bad minute');
      expect(await sessions.read(), _stored);
    });

    testWidgets('a provider that keeps failing is asked again, not once',
        (WidgetTester tester) async {
      // A renewal that failed must not leave the shell believing one is still
      // in flight — that is the in-flight guard latching, and it would be this
      // defect back with no way to recover but a relaunch.
      //
      // **A spent token that could not be replaced is retried at the check
      // interval**, deliberately and with no backoff. Nothing was learned, so
      // the credential and the cadence both stand; a device that is offline is
      // failing every other request too, and the minute after the network
      // returns is when a player coming off a plane wants their series to sync.
      await _pump(
          tester, sessions: sessions, provider: provider, clock: clock);

      provider.refuseWith = const AuthUnreachable<String>('no route to host');
      await clock.advance(tester, tokenReuseWindow + const Duration(minutes: 1));
      final int whileOffline = provider.asked.length;
      expect(whileOffline, greaterThan(1),
          reason: 'the shell gave up after one failure');

      provider.refuseWith = null;
      await clock.advance(tester, const Duration(minutes: 2));

      expect(provider.asked.length, greaterThan(whileOffline));
      expect(_profile(tester).session!.accessToken, isNot('token.1'),
          reason: 'the provider came back and the shell never noticed');
    });
  });

  testWidgets('the shell mints once for a window, however often it looks',
      (WidgetTester tester) async {
    // Two roots and a timer can all notice a spent token in the same frame.
    // Without an in-flight guard that is three `GET /token` for one renewal.
    await _pump(tester, sessions: sessions, provider: provider, clock: clock);

    await clock.advance(tester, tokenReuseWindow * 2);

    expect(provider.asked.length, 2,
        reason: 'one spent token produced more than one mint');
  });

  testWidgets('nothing is left running after the shell is gone',
      (WidgetTester tester) async {
    // A periodic check that outlives its widget is a timer the framework
    // reports and a renewal firing against a disposed State.
    await _pump(tester, sessions: sessions, provider: provider, clock: clock);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
