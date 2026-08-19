import 'package:flutter/widgets.dart';

import '../../../api/auth_client.dart';
import '../../../api/me.dart';
import '../policy/age_gate.dart';
import 'age_gate_screen.dart';
import 'create_account_screen.dart';
import 'tutor_consent_screen.dart';
import 'verify_email_screen.dart';

/// What the flow produced: an account, verified, with the token the AkiMath
/// server verifies and the band the link request has to carry.
@immutable
class LinkedAccount {
  const LinkedAccount({
    required this.accessToken,
    required this.ageBand,
    required this.email,
  });

  final String accessToken;
  final AgeBand ageBand;
  final String email;
}

/// The account flow, `req-age-gate` first.
///
/// **The gate is structural, not a check.** The band is resolved on the first
/// screen and anything below the threshold reaches `TutorConsentScreen`; there
/// is no state in which `CreateAccountScreen` is built without a band, because
/// the field holding it is what selects the screen.
///
/// The order is the provider's: sign up, ask for a code (the provider sends none
/// on sign-up), verify, then `GET /token` for the JWT. Each step's failure is a
/// message on the screen it came from rather than a thrown exception.
class AuthFlow extends StatefulWidget {
  const AuthFlow({
    super.key,
    required this.auth,
    required this.callbackUrl,
    required this.today,
    required this.onLinked,
    required this.onGaveUp,
  });

  final AuthApi auth;

  /// Absolute, or the provider answers `MISSING_ORIGIN` — a mobile app has no
  /// origin to send.
  final String callbackUrl;
  final DateTime today;
  final void Function(LinkedAccount account) onLinked;
  final VoidCallback onGaveUp;

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

enum _Step { age, consent, create, verify }

class _AuthFlowState extends State<AuthFlow> {
  _Step _step = _Step.age;
  AgeBand? _band;
  String _email = '';
  String? _problem;
  bool _busy = false;
  DateTime _codeIssuedAt = DateTime.now();

  void _resolved(AgeBand band, AgeGateRoute route) {
    setState(() {
      _band = band;
      _step = route == AgeGateRoute.createAccount ? _Step.create : _Step.consent;
    });
  }

  Future<void> _create(String email, String password) async {
    setState(() {
      _busy = true;
      _problem = null;
      _email = email;
    });

    final AuthResult<Accepted> created = await widget.auth.signUp(
      email: email,
      password: password,
      callbackUrl: widget.callbackUrl,
    );
    if (!mounted) {
      return;
    }
    final String? failure = _explain(created);
    if (failure != null) {
      setState(() {
        _busy = false;
        _problem = failure;
      });
      return;
    }
    await _requestCode(moveOn: true);
  }

  Future<void> _requestCode({bool moveOn = false}) async {
    setState(() => _busy = true);
    final AuthResult<Accepted> sent = await widget.auth.sendVerificationCode(_email);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _problem = _explain(sent);
      if (_problem == null) {
        _codeIssuedAt = DateTime.now();
        if (moveOn) {
          _step = _Step.verify;
        }
      }
    });
  }

  Future<void> _verify(String code) async {
    setState(() {
      _busy = true;
      _problem = null;
    });

    final AuthResult<AuthSession> verified =
        await widget.auth.verifyEmail(email: _email, code: code);
    if (!mounted) {
      return;
    }
    if (verified is! AuthOk<AuthSession>) {
      setState(() {
        _busy = false;
        _problem = _explain(verified) ?? 'No pudimos confirmar el código.';
      });
      return;
    }

    final AuthResult<String> token = await widget.auth.accessToken(verified.value);
    if (!mounted) {
      return;
    }
    if (token is! AuthOk<String>) {
      setState(() {
        _busy = false;
        _problem = _explain(token) ?? 'La cuenta quedó lista pero no pudimos entrar.';
      });
      return;
    }

    setState(() => _busy = false);
    widget.onLinked(LinkedAccount(
      accessToken: token.value,
      ageBand: _band!,
      email: _email,
    ));
  }

  /// A failure as something a person can read, or null if it was not one.
  ///
  /// **The provider's own message is shown for a refusal.** It is the only thing
  /// that distinguishes "that address is taken" from "that code expired", and
  /// inventing es-MX copy for codes nobody has enumerated would be guessing at
  /// which is which. A refusal is the player's to act on; the other two are not.
  String? _explain(AuthResult<Object?> result) => switch (result) {
    AuthOk<Object?>() => null,
    AuthRefused<Object?>(:final String message, :final String code) =>
      message.isNotEmpty ? message : code,
    AuthFailed<Object?>() => 'Algo falló de nuestro lado. Inténtalo otra vez.',
    AuthUnreachable<Object?>() => 'Sin conexión. Revisa tu internet.',
  };

  @override
  Widget build(BuildContext context) => switch (_step) {
    _Step.age => AgeGateScreen(today: widget.today, onResolved: _resolved),
    _Step.consent => TutorConsentScreen(onBack: widget.onGaveUp),
    _Step.create => CreateAccountScreen(
      onSubmit: _create,
      busy: _busy,
      problem: _problem,
    ),
    _Step.verify => VerifyEmailScreen(
      email: _email,
      codeIssuedAt: _codeIssuedAt,
      onSubmit: _verify,
      onResend: _requestCode,
      busy: _busy,
      problem: _problem,
    ),
  };
}
