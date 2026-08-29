import 'package:akimath_app/api/auth_client.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/features/auth/policy/adults_only_copy.dart';
import 'package:akimath_app/features/auth/ui/adults_only_screen.dart';
import 'package:akimath_app/features/auth/ui/auth_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for Neon Auth, in memory.
///
/// **Not a socket, deliberately.** `testWidgets` runs in a fake-async zone, so
/// a real request completes on a clock the test does not control. The real
/// client is exercised against a real `HttpServer` in `api/auth_client_test.dart`,
/// which is a plain `test()`; what this file is about is the flow between the
/// screens.
class _Provider implements AuthApi {
  _Provider({
    this.signUpRefusal,
    this.verifyRefusal,
    this.signInRefusal,
    this.recoveryRefusal,
    this.resetRefusal,
  });

  final AuthRefused<Accepted>? signUpRefusal;
  final AuthRefused<AuthSession>? verifyRefusal;
  final AuthRefused<AuthSession>? signInRefusal;
  final AuthRefused<Accepted>? recoveryRefusal;
  final AuthRefused<Accepted>? resetRefusal;
  final List<String> calls = <String>[];
  String? recoveryAskedFor;
  String? resetWith;

  @override
  Future<AuthResult<Accepted>> signUp({
    required String email,
    required String password,
    required String callbackUrl,
  }) async {
    calls.add('signUp');
    return signUpRefusal ?? const AuthOk<Accepted>(Accepted());
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
    return verifyRefusal ??
        const AuthOk<AuthSession>(AuthSession('session_token=abc'));
  }

  @override
  Future<AuthResult<AuthSession>> signIn({
    required String email,
    required String password,
  }) async {
    calls.add('signIn');
    return signInRefusal ?? const AuthOk<AuthSession>(AuthSession('session_token=abc'));
  }

  @override
  Future<AuthResult<Accepted>> sendPasswordReset({
    required String email,
    required String redirectTo,
  }) async {
    calls.add('sendPasswordReset');
    recoveryAskedFor = email;
    return recoveryRefusal ?? const AuthOk<Accepted>(Accepted());
  }

  @override
  Future<AuthResult<Accepted>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    calls.add('resetPassword');
    resetWith = '$token/$newPassword';
    return resetRefusal ?? const AuthOk<Accepted>(Accepted());
  }

  @override
  Future<AuthResult<String>> accessToken(AuthSession session) async {
    calls.add('accessToken');
    return const AuthOk<String>('header.payload.signature');
  }
}

extension on WidgetTester {
  /// Presses a pad key by its id, the way the round and puzzle suites do.
  Future<void> pressKey(String id) async {
    await tap(
      find.byWidgetPredicate(
        (Widget w) => w is KeypadKeyView && w.data.id == id,
      ),
    );
    await pump();
  }

  Future<void> typeDigits(String digits) async {
    for (final String digit in digits.split('')) {
      await pressKey(digit);
    }
  }
}

void main() {
  late _Provider provider;
  LinkedAccount? linked;
  bool gaveUp = false;

  /// How many times the flow asked the AkiMath server who the token belongs to.
  ///
  /// **The create path must never ask.** It resolved a band on the first
  /// screen, so a lookup there would be a second answer to a settled question —
  /// and the count is what lets a test say so rather than assume it.
  int meLookups = 0;

  /// What `GET /me` answers, for the sign-in door that asks it.
  ///
  /// Settable because the band it carries is the **second source of a band** in
  /// this flow — a returning player's comes off the server, not off the gate —
  /// and ADR 0004 has to reach both.
  MeResult meAnswer = const MeNoPlayer();

  Future<MeResult> lookUpMe(String accessToken) async {
    meLookups += 1;
    return meAnswer;
  }

  Future<void> pumpFlow(
    WidgetTester tester, {
    String? born,
    AuthEntry entry = AuthEntry.createAccount,
  }) async {
    linked = null;
    gaveUp = false;
    meLookups = 0;
    meAnswer = const MeNoPlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthFlow(
            auth: provider,
            whoAmI: lookUpMe,
            entry: entry,
            callbackUrl: 'akimath://verified',
            today: DateTime.utc(2026, 8, 19),
            onLinked: (LinkedAccount account) => linked = account,
            onGaveUp: () => gaveUp = true,
          ),
        ),
      ),
    );
    if (born != null) {
      await tester.typeDigits(born);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'the age gate stands in front, and a minor never reaches the form',
    (WidgetTester tester) async {
      provider = _Provider();
      await pumpFlow(tester, born: '19082016'); // 10 years old

      expect(find.byType(AdultsOnlyScreen), findsOneWidget);
      expect(find.text('Crear cuenta'), findsNothing);

      // `req-no-account-without-a-declaration`: no path from here reaches the
      // form. The trail is cleared on the way in, so the one control leaves the
      // flow rather than stepping back into the gate.
      await tester.tap(find.text(adultsOnlyDoorLabel));
      await tester.pumpAndSettle();
      expect(gaveUp, isTrue);
      expect(find.text('Crear cuenta'), findsNothing);
    },
  );

  testWidgets('a seventeen-year-old is refused, and that band used to pass', (
    WidgetTester tester,
  ) async {
    // **The live behaviour ADR 0004 changes.** `13_17` reached the account form
    // before this decision, created an account and synced. It does not now, and
    // this is the case that says so rather than leaving it to the policy test.
    provider = _Provider();
    await pumpFlow(tester, born: '20082008'); // turns 18 tomorrow

    expect(find.byType(AdultsOnlyScreen), findsOneWidget);
    expect(find.byKey(const Key('create-account-email')), findsNothing);
    expect(linked, isNull);
  });

  testWidgets('a band at the threshold reaches the form', (
    WidgetTester tester,
  ) async {
    provider = _Provider();
    await pumpFlow(tester, born: '19082008'); // 18 exactly, today

    expect(find.text('Crear cuenta'), findsWidgets);
    expect(find.byType(AdultsOnlyScreen), findsNothing);
  });

  testWidgets('an impossible date is refused without leaving the gate', (
    WidgetTester tester,
  ) async {
    provider = _Provider();
    await pumpFlow(tester);

    await tester.typeDigits('30022026');
    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(find.byKey(const Key('age-gate-problem')), findsOneWidget);
    expect(find.text('Crear cuenta'), findsNothing);
  });

  testWidgets('the whole way through: account, code, token', (
    WidgetTester tester,
  ) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');

    await tester.enterText(
      find.byKey(const Key('create-account-email')),
      'alguien@ejemplo.com',
    );
    await tester.enterText(
      find.byKey(const Key('create-account-password')),
      'una-contra-larga',
    );
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();

    // **One call, not two.** Sign-up already issues the code; asking for
    // another invalidated the first, and the player who typed the code that
    // arrived first was told it was wrong.
    expect(provider.calls, <String>['signUp']);
    expect(find.text('REVISA TU CORREO'), findsOneWidget);
    expect(find.textContaining('alguien@ejemplo.com'), findsOneWidget);

    await tester.typeDigits('123456');
    await tester.pressKey('enter');
    await tester.pumpAndSettle();

    expect(provider.calls.last, 'accessToken');
    expect(linked, isNotNull);
    expect(linked!.accessToken, 'header.payload.signature');
    expect(linked!.email, 'alguien@ejemplo.com');
    expect(linked!.ageBand, AgeBand.adult);
    // **The cookie the token was derived from travels with it.** An access
    // token expires in minutes, so it is the wrong thing to keep; this is what
    // a later launch re-derives one from. The flow held it and dropped it
    // before building the account, which made the whole persistence path
    // dormant while every one of its own tests stayed green.
    expect(linked!.provider, const AuthSession('session_token=abc'));
    // **The create path never asks the server for a band.** It has one, from
    // the gate, and a lookup here would be a second answer to a settled
    // question — the sign-in door asks precisely because it has no gate behind
    // it.
    expect(meLookups, 0);
  });

  testWidgets(
    'a refusal is shown where it happened, in the provider\'s words',
    (WidgetTester tester) async {
      provider = _Provider(
        signUpRefusal: const AuthRefused<Accepted>(
          status: 400,
          code: 'USER_ALREADY_EXISTS',
          message: 'Ese correo ya existe.',
        ),
      );
      await pumpFlow(tester, born: '14031990');

      await tester.enterText(
        find.byKey(const Key('create-account-email')),
        'alguien@ejemplo.com',
      );
      await tester.enterText(
        find.byKey(const Key('create-account-password')),
        'una-contra-larga',
      );
      await tester.tap(find.text('Crear cuenta').last);
      await tester.pumpAndSettle();

      // Still on the form, with the reason under it — not on the code screen.
      expect(find.byKey(const Key('create-account-problem')), findsOneWidget);
      expect(find.text('Ese correo ya existe.'), findsOneWidget);
      expect(find.text('REVISA TU CORREO'), findsNothing);
    },
  );

  testWidgets('a bad code keeps the code screen and says so', (
    WidgetTester tester,
  ) async {
    provider = _Provider(
      verifyRefusal: const AuthRefused<AuthSession>(
        status: 400,
        code: 'INVALID_OTP',
        message: 'Código incorrecto.',
      ),
    );
    await pumpFlow(tester, born: '14031990');

    await tester.enterText(
      find.byKey(const Key('create-account-email')),
      'alguien@ejemplo.com',
    );
    await tester.enterText(
      find.byKey(const Key('create-account-password')),
      'una-contra-larga',
    );
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();

    await tester.typeDigits('000000');
    await tester.pressKey('enter');
    await tester.pumpAndSettle();

    expect(find.text('Código incorrecto.'), findsOneWidget);
    expect(linked, isNull);
  });

  testWidgets('the form refuses a short password before any request', (
    WidgetTester tester,
  ) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');

    await tester.enterText(
      find.byKey(const Key('create-account-email')),
      'alguien@ejemplo.com',
    );
    await tester.enterText(
      find.byKey(const Key('create-account-password')),
      'corta',
    );
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-account-problem')), findsOneWidget);
    expect(provider.calls, isEmpty);
  });

  testWidgets('an empty field is asked for a date, never accused of one', (
    WidgetTester tester,
  ) async {
    provider = _Provider();
    await pumpFlow(tester);

    await tester.tap(find.text('Continuar'));
    await tester.pump();

    // **The message a player is left holding has to be true of what they see.**
    // The flow lives in a tab an `IndexedStack` keeps alive, so this refusal
    // survives a trip to another tab and back — measured, not assumed. Over an
    // empty `DD/MM/AAAA` that made `Revisa la fecha.` an accusation about a
    // date nobody had typed. A prompt is true however long it stays up.
    expect(find.text('Escribe tu fecha de nacimiento.'), findsOneWidget);
    expect(find.text('Revisa la fecha.'), findsNothing);
  });

  testWidgets(
    'a date that was typed and is wrong is still told to be checked',
    (WidgetTester tester) async {
      provider = _Provider();
      await pumpFlow(tester);

      await tester.typeDigits('3002');
      await tester.tap(find.text('Continuar'));
      await tester.pump();

      expect(find.text('Revisa la fecha.'), findsOneWidget);
      expect(find.text('Escribe tu fecha de nacimiento.'), findsNothing);
    },
  );

  testWidgets('the age gate has a way out, and it leaves the flow', (
    WidgetTester tester,
  ) async {
    provider = _Provider();
    await pumpFlow(tester);

    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();

    expect(gaveUp, isTrue);
  });

  testWidgets('back from the form returns to the gate', (
    WidgetTester tester,
  ) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');
    expect(find.byKey(const Key('create-account-email')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('age-gate-date')), findsOneWidget);
    expect(gaveUp, isFalse);
  });

  testWidgets('back from the code screen returns to the form', (
    WidgetTester tester,
  ) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');
    await tester.enterText(
      find.byKey(const Key('create-account-email')),
      'alguien@ejemplo.com',
    );
    await tester.enterText(
      find.byKey(const Key('create-account-password')),
      'una-contra-larga',
    );
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('verify-code')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-account-email')), findsOneWidget);
    expect(gaveUp, isFalse);
  });

  /// Reaches `1.1` the way a returning player does: through the gate, then the
  /// door the form offers.
  Future<void> reachSignIn(WidgetTester tester) async {
    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();
  }

  testWidgets('a returning player reaches sign-in from the form',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');

    await reachSignIn(tester);

    expect(find.text('INICIA SESIÓN'), findsOneWidget);
    expect(find.byKey(const Key('sign-in-email')), findsOneWidget);
    expect(find.byKey(const Key('sign-in-password')), findsOneWidget);
  });

  testWidgets('signing in links the account, with the band from the gate',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');
    await reachSignIn(tester);

    await tester.enterText(
        find.byKey(const Key('sign-in-email')), 'alguien@ejemplo.com');
    await tester.enterText(
        find.byKey(const Key('sign-in-password')), 'una-contra-larga');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    // No account is created and no code is asked for: the account exists.
    expect(provider.calls, <String>['signIn', 'accessToken']);
    expect(linked, isNotNull);
    expect(linked!.email, 'alguien@ejemplo.com');
    expect(linked!.ageBand, AgeBand.adult);
    expect(linked!.accessToken, 'header.payload.signature');
  });

  testWidgets('a band the server already stores is refused the same way',
      (WidgetTester tester) async {
    // **The second source of a band, and the one that is easy to miss.** A
    // returning player's band comes off `GET /me`, never off the gate — so a
    // gate that refused and a sign-in door that did not would be one fact
    // producing opposite answers depending on which side of the wire it was
    // read from. Both go through `AgeGate.next`, which is why there is one
    // decision here rather than two.
    //
    // **Reachable rather than hypothetical**: `13_17` reached the account form
    // before ADR 0004, so rows carrying it exist and the frozen `CHECK` still
    // permits them (this change narrows nothing under `packages/`).
    //
    // Entered through the sign-in door, which is the only way to reach this
    // path: the create door resolves a band on the gate first, and a band in
    // hand is never asked of the server a second time.
    provider = _Provider();
    await pumpFlow(tester, entry: AuthEntry.signIn);
    meAnswer = MeFound(Me(
      playerId: '8f14e45f-ceea-4167-a5b0-9c0e2f3a1b2c',
      ageBand: AgeBand.thirteenToSeventeen,
      createdAt: DateTime.utc(2026, 8, 1),
    ));

    await tester.enterText(
        find.byKey(const Key('sign-in-email')), 'alguien@ejemplo.com');
    await tester.enterText(
        find.byKey(const Key('sign-in-password')), 'una-contra-larga');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.byType(AdultsOnlyScreen), findsOneWidget);
    // **The session in hand is dropped.** The provider granted one — we cannot
    // stop it — but nothing this app holds carries it onward, so no link
    // request is made and the shell never learns of an account.
    expect(linked, isNull);
  });

  testWidgets('a refused sign-in stays put, in the provider\'s words',
      (WidgetTester tester) async {
    provider = _Provider(
      signInRefusal: const AuthRefused<AuthSession>(
        status: 401,
        code: 'INVALID_EMAIL_OR_PASSWORD',
        message: 'Ese correo y esa contraseña no coinciden.',
      ),
    );
    await pumpFlow(tester, born: '14031990');
    await reachSignIn(tester);

    await tester.enterText(
        find.byKey(const Key('sign-in-email')), 'alguien@ejemplo.com');
    await tester.enterText(
        find.byKey(const Key('sign-in-password')), 'la-que-no-es');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Ese correo y esa contraseña no coinciden.'), findsOneWidget);
    expect(linked, isNull);
    // `accessToken` is never asked for without a session.
    expect(provider.calls, <String>['signIn']);
  });

  testWidgets('sign-in refuses a malformed address before any request',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');
    await reachSignIn(tester);

    await tester.enterText(find.byKey(const Key('sign-in-email')), 'no-es-correo');
    await tester.enterText(
        find.byKey(const Key('sign-in-password')), 'una-contra-larga');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sign-in-problem')), findsOneWidget);
    expect(provider.calls, isEmpty);
  });

  testWidgets('back from sign-in returns to the form', (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');
    await reachSignIn(tester);

    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-account-email')), findsOneWidget);
    expect(gaveUp, isFalse);
  });

  testWidgets('recovery is reached from sign-in, carrying the address typed',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');
    await reachSignIn(tester);
    await tester.enterText(
        find.byKey(const Key('sign-in-email')), 'alguien@ejemplo.com');

    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    expect(find.text('TE MANDAMOS UN ENLACE'), findsOneWidget);
    // Typed once, not twice.
    expect(find.text('alguien@ejemplo.com'), findsOneWidget);
  });

  testWidgets('the sent screen says "if that account exists", because that is '
      'all the provider tells us', (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');
    await reachSignIn(tester);
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('recover-email')), 'alguien@ejemplo.com');
    await tester.tap(find.text('Enviar el enlace'));
    await tester.pumpAndSettle();

    expect(provider.calls, <String>['sendPasswordReset']);
    expect(provider.recoveryAskedFor, 'alguien@ejemplo.com');
    // **Better Auth answers the same for an address with no account**, so a
    // flat "te lo mandamos" would be a claim nobody can stand behind.
    expect(find.textContaining('Si esa cuenta existe'), findsOneWidget);
  });

  testWidgets('a provider that cannot send says so instead of claiming it did',
      (WidgetTester tester) async {
    provider = _Provider(
      recoveryRefusal: const AuthRefused<Accepted>(
        status: 400,
        code: 'RESET_PASSWORD_NOT_ENABLED',
        message: "Reset password isn't enabled",
      ),
    );
    await pumpFlow(tester, born: '14031990');
    await reachSignIn(tester);
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('recover-email')), 'alguien@ejemplo.com');
    await tester.tap(find.text('Enviar el enlace'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recover-problem')), findsOneWidget);
    expect(find.textContaining('Si esa cuenta existe'), findsNothing);
  });

  testWidgets('recovery refuses a malformed address before any request',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');
    await reachSignIn(tester);
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('recover-email')), 'nope');
    await tester.tap(find.text('Enviar el enlace'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recover-problem')), findsOneWidget);
    expect(provider.calls, isEmpty);
  });

  testWidgets('back from recovery returns to sign-in', (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');
    await reachSignIn(tester);
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sign-in-email')), findsOneWidget);
  });

  /// The flow opened on a reset token, which is how `1.5` is entered.
  Future<void> pumpReset(WidgetTester tester, {String token = 'tok-123'}) async {
    linked = null;
    gaveUp = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AuthFlow(
          auth: provider,
          whoAmI: lookUpMe,
          callbackUrl: 'https://auth.example/neondb/auth',
          today: DateTime.utc(2026, 8, 19),
          onLinked: (LinkedAccount account) => linked = account,
          onGaveUp: () => gaveUp = true,
          resetToken: token,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a reset token opens the new-password screen, not the gate',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpReset(tester);

    expect(find.text('CONTRASEÑA NUEVA'), findsOneWidget);
    expect(find.byKey(const Key('age-gate-date')), findsNothing);
  });

  testWidgets('the new password reaches the provider with its token',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpReset(tester);

    await tester.enterText(
        find.byKey(const Key('new-password')), 'una-contra-larga');
    await tester.enterText(
        find.byKey(const Key('new-password-again')), 'una-contra-larga');
    await tester.tap(find.text('Guardar la contraseña'));
    await tester.pumpAndSettle();

    expect(provider.calls, <String>['resetPassword']);
    expect(provider.resetWith, 'tok-123/una-contra-larga');
    expect(find.byKey(const Key('new-password-done')), findsOneWidget);
  });

  testWidgets('two passwords that differ never reach the provider',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpReset(tester);

    await tester.enterText(
        find.byKey(const Key('new-password')), 'una-contra-larga');
    await tester.enterText(
        find.byKey(const Key('new-password-again')), 'otra-contra-larga');
    await tester.tap(find.text('Guardar la contraseña'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('new-password-problem')), findsOneWidget);
    expect(provider.calls, isEmpty);
  });

  testWidgets('a short password is refused before the round trip',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpReset(tester);

    await tester.enterText(find.byKey(const Key('new-password')), 'corta');
    await tester.enterText(find.byKey(const Key('new-password-again')), 'corta');
    await tester.tap(find.text('Guardar la contraseña'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('new-password-problem')), findsOneWidget);
    expect(provider.calls, isEmpty);
  });

  testWidgets('an expired token is said out loud, not swallowed',
      (WidgetTester tester) async {
    provider = _Provider(
      resetRefusal: const AuthRefused<Accepted>(
        status: 400,
        code: 'INVALID_TOKEN',
        message: 'Ese enlace ya venció.',
      ),
    );
    await pumpReset(tester);

    await tester.enterText(
        find.byKey(const Key('new-password')), 'una-contra-larga');
    await tester.enterText(
        find.byKey(const Key('new-password-again')), 'una-contra-larga');
    await tester.tap(find.text('Guardar la contraseña'));
    await tester.pumpAndSettle();

    expect(find.text('Ese enlace ya venció.'), findsOneWidget);
    expect(find.byKey(const Key('new-password-done')), findsNothing);
  });
}
