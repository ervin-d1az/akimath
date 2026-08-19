import 'package:akimath_app/api/auth_client.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
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
  _Provider({this.signUpRefusal, this.verifyRefusal});

  final AuthRefused<Accepted>? signUpRefusal;
  final AuthRefused<AuthSession>? verifyRefusal;
  final List<String> calls = <String>[];

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
    return verifyRefusal ?? const AuthOk<AuthSession>(AuthSession('session_token=abc'));
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
    await tap(find.byWidgetPredicate(
      (Widget w) => w is KeypadKeyView && w.data.id == id,
    ));
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

  Future<void> pumpFlow(WidgetTester tester, {String? born}) async {
    linked = null;
    gaveUp = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AuthFlow(
          auth: provider,
          callbackUrl: 'akimath://verified',
          today: DateTime.utc(2026, 8, 19),
          onLinked: (LinkedAccount account) => linked = account,
          onGaveUp: () => gaveUp = true,
        ),
      ),
    ));
    if (born != null) {
      await tester.typeDigits(born);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the age gate stands in front, and a child never reaches the form',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '19082016'); // 10 years old

    expect(find.text('Sigue jugando'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsNothing);

    // `req-age-gate`: no path from here reaches the form.
    await tester.tap(find.text('Volver a los retos'));
    await tester.pumpAndSettle();
    expect(gaveUp, isTrue);
  });

  testWidgets('a band at the threshold reaches the form', (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '19082013'); // 13 exactly, today

    expect(find.text('Crear cuenta'), findsWidgets);
    expect(find.text('Sigue jugando'), findsNothing);
  });

  testWidgets('an impossible date is refused without leaving the gate',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester);

    await tester.typeDigits('30022026');
    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(find.byKey(const Key('age-gate-problem')), findsOneWidget);
    expect(find.text('Crear cuenta'), findsNothing);
  });

  testWidgets('the whole way through: account, code, token', (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');

    await tester.enterText(
        find.byKey(const Key('create-account-email')), 'alguien@ejemplo.com');
    await tester.enterText(
        find.byKey(const Key('create-account-password')), 'una-contra-larga');
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();

    // **One call, not two.** Sign-up already issues the code; asking for
    // another invalidated the first, and the player who typed the code that
    // arrived first was told it was wrong.
    expect(provider.calls, <String>['signUp']);
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.textContaining('alguien@ejemplo.com'), findsOneWidget);

    await tester.typeDigits('123456');
    await tester.pressKey('enter');
    await tester.pumpAndSettle();

    expect(provider.calls.last, 'accessToken');
    expect(linked, isNotNull);
    expect(linked!.accessToken, 'header.payload.signature');
    expect(linked!.email, 'alguien@ejemplo.com');
    expect(linked!.ageBand, AgeBand.adult);
  });

  testWidgets('a refusal is shown where it happened, in the provider\'s words',
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
        find.byKey(const Key('create-account-email')), 'alguien@ejemplo.com');
    await tester.enterText(
        find.byKey(const Key('create-account-password')), 'una-contra-larga');
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();

    // Still on the form, with the reason under it — not on the code screen.
    expect(find.byKey(const Key('create-account-problem')), findsOneWidget);
    expect(find.text('Ese correo ya existe.'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);
  });

  testWidgets('a bad code keeps the code screen and says so', (WidgetTester tester) async {
    provider = _Provider(
      verifyRefusal: const AuthRefused<AuthSession>(
        status: 400,
        code: 'INVALID_OTP',
        message: 'Código incorrecto.',
      ),
    );
    await pumpFlow(tester, born: '14031990');

    await tester.enterText(
        find.byKey(const Key('create-account-email')), 'alguien@ejemplo.com');
    await tester.enterText(
        find.byKey(const Key('create-account-password')), 'una-contra-larga');
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();

    await tester.typeDigits('000000');
    await tester.pressKey('enter');
    await tester.pumpAndSettle();

    expect(find.text('Código incorrecto.'), findsOneWidget);
    expect(linked, isNull);
  });

  testWidgets('the form refuses a short password before any request',
      (WidgetTester tester) async {
    provider = _Provider();
    await pumpFlow(tester, born: '14031990');

    await tester.enterText(
        find.byKey(const Key('create-account-email')), 'alguien@ejemplo.com');
    await tester.enterText(find.byKey(const Key('create-account-password')), 'corta');
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-account-problem')), findsOneWidget);
    expect(provider.calls, isEmpty);
  });
}
