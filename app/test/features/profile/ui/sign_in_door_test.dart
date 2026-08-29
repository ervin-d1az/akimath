import 'package:akimath_app/api/auth_client.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/auth/ui/adults_only_screen.dart';
import 'package:akimath_app/features/auth/ui/age_gate_screen.dart';
import 'package:akimath_app/features/auth/ui/create_account_screen.dart';
import 'package:akimath_app/features/auth/ui/sign_in_screen.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether a returning player can **reach** `Iniciar sesión` from the
/// profile without being asked when they were born.
///
/// **This exists because the only entrance was inside `Crear cuenta`.** A
/// player who already had an account had to press *Crear cuenta*, answer
/// *¿Cuándo naciste?*, reach the sign-up form and find a text link at the
/// bottom of it. Reported twice from a device, unprompted, as *"it's hard to
/// find"* and *"I feel like it's very hidden"*.
///
/// The band is what made that door defensible: `LinkedAccount.ageBand` is
/// required, `players.age_band` is what the device declared, and only the gate
/// resolves one. Signing in resolves it a second honest way — `GET /me` reports
/// the band the server already stores — so the gate is needed only where a link
/// is, which is one of the two things these tests pin.
///
/// **The other is that both sources are judged.** After ADR 0004 the band is no
/// longer a route into child protections or out of them; it is an eligibility
/// declaration, and a band below adulthood ends the flow whichever side of the
/// wire it was read from.
class _Provider implements AuthApi {
  _Provider();

  final List<String> calls = <String>[];

  @override
  Future<AuthResult<Accepted>> signUp({
    required String email,
    required String password,
    required String callbackUrl,
  }) async {
    calls.add('signUp');
    return const AuthOk<Accepted>(Accepted());
  }

  @override
  Future<AuthResult<Accepted>> sendVerificationCode(String email) async {
    calls.add('sendVerificationCode');
    return const AuthOk<Accepted>(Accepted());
  }

  @override
  Future<AuthResult<AuthSession>> verifyEmail({
    required String email,
    required String code,
  }) async {
    calls.add('verifyEmail');
    return const AuthOk<AuthSession>(AuthSession('session_token=abc'));
  }

  @override
  Future<AuthResult<AuthSession>> signIn({
    required String email,
    required String password,
  }) async {
    calls.add('signIn');
    return const AuthOk<AuthSession>(AuthSession('session_token=abc'));
  }

  @override
  Future<AuthResult<Accepted>> sendPasswordReset({
    required String email,
    required String redirectTo,
  }) async {
    calls.add('sendPasswordReset');
    return const AuthOk<Accepted>(Accepted());
  }

  @override
  Future<AuthResult<Accepted>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    calls.add('resetPassword');
    return const AuthOk<Accepted>(Accepted());
  }

  @override
  Future<AuthResult<String>> accessToken(AuthSession session) async {
    calls.add('accessToken');
    return const AuthOk<String>('jwt');
  }
}

/// The shell's own job, small enough to do here: hold the session and rebuild
/// the route with it. Without it nothing can check that signing in shows on the
/// profile without a relaunch, because the route does not own what it displays.
class _Shell extends StatefulWidget {
  const _Shell({
    required this.auth,
    required this.whoAmI,
    required this.onSession,
    this.startsSignedInAs,
    this.linkResult,
  });

  final AuthApi auth;
  final Future<MeResult> Function(String accessToken) whoAmI;

  /// A session the device is already holding when the profile opens.
  final LinkedSession? startsSignedInAs;

  /// What `POST /players/link` says about that session. A refusal is the state
  /// this file's last case is about.
  final LinkResult? linkResult;

  /// Reports what the shell was handed, so a test can read the band rather
  /// than infer it from an address on screen.
  final ValueChanged<LinkedSession?> onSession;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late LinkedSession? _session = widget.startsSignedInAs;

  @override
  Widget build(BuildContext context) => ProfileRoute(
        session: _session,
        onSessionChanged: (LinkedSession? session) {
          widget.onSession(session);
          setState(() => _session = session);
        },
        now: () => DateTime.utc(2026, 8, 20),
        authBaseUrl: 'https://auth.example/neondb/auth',
        auth: widget.auth,
        whoAmI: widget.whoAmI,
        link: ({
          required String accessToken,
          required String playerId,
          required AgeBand ageBand,
        }) async =>
            widget.linkResult ??
            LinkDone(Me(
              playerId: playerId,
              ageBand: ageBand,
              createdAt: DateTime.utc(2026, 8, 20),
            )),
        fetchHistory: (String accessToken) async => const HistoryNoPlayer(),
      );
}

Future<void> _pump(
  WidgetTester tester, {
  required AuthApi auth,
  required Future<MeResult> Function(String accessToken) whoAmI,
  ValueChanged<LinkedSession?> onSession = _ignore,
  LinkedSession? startsSignedInAs,
  LinkResult? linkResult,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: _Shell(
        auth: auth,
        whoAmI: whoAmI,
        onSession: onSession,
        startsSignedInAs: startsSignedInAs,
        linkResult: linkResult,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _ignore(LinkedSession? session) {}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(
    find.byType(EditableText).first,
    'ana@correo.mx',
  );
  await tester.enterText(find.byType(EditableText).last, 'unaContraseña1');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  final Me linkedPlayer = Me(
    playerId: '8f14e45f-ceea-4167-a5b0-9c0e2f3a1b2c',
    // **`adult` now, and the sensitivity it used to provide moved.** This was
    // `13_17` so that a `?? adult` default could not satisfy the assertion;
    // after ADR 0004 a minor's band is refused, so a fixture carrying one
    // would refuse every test that shares it. The two cases below carry the
    // guard instead — each of them fails if a band is ever defaulted, because
    // each expects a *refusal* that `adult` does not produce.
    ageBand: AgeBand.adult,
    createdAt: DateTime.utc(2026, 8, 1),
  );

  /// A row the server still holds and this build will not link.
  ///
  /// **Reachable rather than hypothetical.** `13_17` reached the account form
  /// until ADR 0004, so rows carrying it exist, and this change narrows nothing
  /// under `packages/` — the frozen `CHECK` still permits the value.
  final Me minorPlayer = Me(
    playerId: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
    ageBand: AgeBand.thirteenToSeventeen,
    createdAt: DateTime.utc(2026, 8, 1),
  );

  testWidgets('the profile opens 1.1 without asking for a birth date',
      (WidgetTester tester) async {
    await _pump(
      tester,
      auth: _Provider(),
      whoAmI: (String token) async => MeFound(linkedPlayer),
    );

    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    // The whole point: no gate, and no sign-up form to find a link at the
    // bottom of.
    expect(find.byType(AgeGateScreen), findsNothing);
    expect(find.byType(CreateAccountScreen), findsNothing);
  });

  testWidgets('and Crear cuenta still opens the gate',
      (WidgetTester tester) async {
    // The gate is not weakened, only bypassed where nothing needs it. A door
    // that made an account without resolving a band would be the failure this
    // whole design is arranged around.
    await _pump(
      tester,
      auth: _Provider(),
      whoAmI: (String token) async => const MeNoPlayer(),
    );

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.byType(AgeGateScreen), findsOneWidget);
  });

  testWidgets('a returning player takes the band the server already stores',
      (WidgetTester tester) async {
    // **The band is read, never guessed.** `GET /me` answers `players.age_band`
    // itself, which is the authoritative value — so the account that comes back
    // is routed the way the server already routes it.
    LinkedSession? handedOver;
    await _pump(
      tester,
      auth: _Provider(),
      whoAmI: (String token) async => MeFound(linkedPlayer),
      onSession: (LinkedSession? session) => handedOver = session,
    );

    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();
    await _signIn(tester);

    expect(find.byType(SignInScreen), findsNothing, reason: 'the flow is still open');
    expect(find.byType(AgeGateScreen), findsNothing, reason: 'it asked anyway');
    expect(handedOver?.ageBand, AgeBand.adult,
        reason: 'the band did not come from the server');
    // The shell learned about it, which is the only way the profile can show
    // the account without a relaunch.
    expect(find.text('ana@correo.mx'), findsWidgets);
  });

  testWidgets('a returning player the server records as a minor is refused',
      (WidgetTester tester) async {
    // **The second source of a band, judged by the same function as the first.**
    // ADR 0004 refuses a minor at the gate; a band read off `GET /me` is the
    // same declaration recorded earlier, so letting it through would be one
    // fact producing opposite answers depending on which side of the wire it
    // was read from.
    LinkedSession? handedOver;
    await _pump(
      tester,
      auth: _Provider(),
      whoAmI: (String token) async => MeFound(minorPlayer),
      onSession: (LinkedSession? session) => handedOver = session,
    );

    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();
    await _signIn(tester);

    expect(find.byType(AdultsOnlyScreen), findsOneWidget);
    // **Nothing was handed over**, so the shell holds no session, no link
    // request is made and the profile does not show the address. The provider
    // granted a session and we cannot withdraw it; what this asserts is that
    // nothing in this app carries it onward.
    expect(handedOver, isNull);
  });

  testWidgets('and the gate it never saw still decides the band it links under',
      (WidgetTester tester) async {
    // The `MeNoPlayer` path all the way through: sign in, be asked, answer, and
    // watch the band the player just declared reach the shell.
    LinkedSession? handedOver;
    await _pump(
      tester,
      auth: _Provider(),
      whoAmI: (String token) async => const MeNoPlayer(),
      onSession: (LinkedSession? session) => handedOver = session,
    );

    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();
    await _signIn(tester);

    for (final String digit in '14031990'.split('')) {
      await tester.tap(find.byWidgetPredicate(
        (Widget w) => w is KeypadKeyView && w.data.id == digit,
      ));
      await tester.pump();
    }
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(handedOver?.ageBand, AgeBand.adult);
    expect(find.byType(CreateAccountScreen), findsNothing,
        reason: 'the account already exists; the gate was only for the band');
  });

  testWidgets('and a minor answering that gate is refused, account or not',
      (WidgetTester tester) async {
    // **The case a `?? adult` cannot pass**, which is the guard `linkedPlayer`
    // used to carry with a `13_17` fixture. A band that was defaulted rather
    // than resolved would hand a session over here; a resolved one refuses.
    //
    // It is also the reachable half of `DELETE /me`'s aftermath: the account
    // survives erasure, so somebody who erased and came back is asked again,
    // and the answer they give now is the one that decides.
    LinkedSession? handedOver;
    await _pump(
      tester,
      auth: _Provider(),
      whoAmI: (String token) async => const MeNoPlayer(),
      onSession: (LinkedSession? session) => handedOver = session,
    );

    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();
    await _signIn(tester);

    for (final String digit in '20082011'.split('')) {
      await tester.tap(find.byWidgetPredicate(
        (Widget w) => w is KeypadKeyView && w.data.id == digit,
      ));
      await tester.pump();
    }
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.byType(AdultsOnlyScreen), findsOneWidget);
    expect(handedOver, isNull);
  });

  testWidgets('an account with no player is asked, because a link needs a band',
      (WidgetTester tester) async {
    // **Reachable, not theoretical.** `DELETE /me` erases the player and leaves
    // the Neon Auth account standing, so a player who erased and signed back in
    // lands exactly here: a live account, no player row, and nothing on the
    // server that could say which band to link under.
    await _pump(
      tester,
      auth: _Provider(),
      whoAmI: (String token) async => const MeNoPlayer(),
    );

    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();
    await _signIn(tester);

    expect(find.byType(AgeGateScreen), findsOneWidget);
    expect(find.text('ana@correo.mx'), findsNothing,
        reason: 'the session was handed over before the band was resolved');
  });

  testWidgets('a refused session is told to come back in and can',
      (WidgetTester tester) async {
    // **`4.1` instructs an action it did not offer.** `AccountState.rejected`
    // draws *"Tu sesión caducó. Vuelve a entrar."* and then nothing: no banner,
    // no retry — asking twice with a dead token gets the same refusal — and no
    // door, because the door required there to be no session and a refused one
    // is still a session. The session lives in memory, so force-quitting the
    // app was the only way back in.
    await _pump(
      tester,
      auth: _Provider(),
      whoAmI: (String token) async => MeFound(linkedPlayer),
      startsSignedInAs: const LinkedSession(
        email: 'ana@correo.mx',
        accessToken: 'a.dead.token',
        ageBand: AgeBand.adult,
      ),
      linkResult: const LinkRejected(
        tag: 'invalid_session',
        message: 'invalid session',
      ),
    );

    expect(find.text('Tu sesión caducó. Vuelve a entrar.'), findsOneWidget);
    // The door says the same words the caption does, because it is the act the
    // caption names.
    expect(find.text('Volver a entrar'), findsOneWidget);
    // Not a second way to make an account: there already is one.
    expect(find.text('Crear cuenta'), findsNothing);

    await tester.tap(find.text('Volver a entrar'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(AgeGateScreen), findsNothing);
  });

  testWidgets('and a healthy session is offered no door at all',
      (WidgetTester tester) async {
    // The door is a recovery, not furniture. A linked account has nothing to
    // recover from, and a control that acts on a state you are not in is the
    // DR-P2 failure the other way round.
    await _pump(
      tester,
      auth: _Provider(),
      whoAmI: (String token) async => MeFound(linkedPlayer),
      startsSignedInAs: const LinkedSession(
        email: 'ana@correo.mx',
        accessToken: 'a.live.token',
        ageBand: AgeBand.adult,
      ),
    );

    expect(find.text('Volver a entrar'), findsNothing);
    expect(find.text('Ya tengo cuenta'), findsNothing);
    expect(find.text('Crear cuenta'), findsNothing);
  });
}
