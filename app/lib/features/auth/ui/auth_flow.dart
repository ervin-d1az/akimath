import 'package:flutter/widgets.dart';

import '../../../api/auth_client.dart';
import '../../../api/me.dart';
import '../policy/age_gate.dart';
import 'age_gate_screen.dart';
import 'create_account_screen.dart';
import 'recover_password_screen.dart';
import 'sign_in_screen.dart';
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

enum _Step { age, consent, create, signIn, recover, verify }

class _AuthFlowState extends State<AuthFlow> {
  /// The steps behind the one on screen, oldest first.
  ///
  /// **A stack rather than a predecessor per step**, because more than one
  /// screen leads to the same place and "where you came from" is the only
  /// answer a back control can give that is never surprising.
  final List<_Step> _trail = <_Step>[_Step.age];

  _Step get _step => _trail.last;

  AgeBand? _band;
  String _email = '';
  String? _problem;
  bool _busy = false;

  /// Whether the provider has accepted a reset request. Set from its answer and
  /// cleared on the way into `1.4`, so a second visit does not open on the
  /// confirmation the first one earned.
  bool _resetSent = false;
  DateTime _codeIssuedAt = DateTime.now();

  /// One rule: back is the step you came from, and behind the first one is the
  /// way out of the flow entirely.
  void _back() {
    if (_trail.length == 1) {
      widget.onGaveUp();
      return;
    }
    setState(() {
      _problem = null;
      _trail.removeLast();
    });
  }

  void _goTo(_Step step) {
    setState(() {
      _problem = null;
      _trail.add(step);
    });
  }

  Future<void> _sendPasswordReset(String email) async {
    setState(() {
      _busy = true;
      _problem = null;
      _email = email;
    });

    final AuthResult<Accepted> asked = await widget.auth.sendPasswordReset(
      email: email,
      // The same trusted origin sign-up uses. A scheme of our own is 403
      // `INVALID_CALLBACK_URL` until somebody adds one in the console.
      redirectTo: widget.callbackUrl,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _problem = _explain(asked);
      // **Only the provider's yes turns this on.** Setting it on the way into
      // the call would show "ya va en camino" to a player whose provider has
      // no reset mailer configured and answered a refusal.
      _resetSent = _problem == null;
    });
  }

  void _resolved(AgeBand band, AgeGateRoute route) {
    setState(() {
      _band = band;
      _problem = null;
      if (route == AgeGateRoute.createAccount) {
        _trail.add(_Step.create);
        return;
      }
      // **Consent replaces the trail rather than extending it**, so
      // `req-age-gate`'s "no path from here reaches 1.2" is true by
      // construction — there is nothing behind consent to go back to, and the
      // one control it draws leaves the flow.
      _trail
        ..clear()
        ..add(_Step.consent);
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
    // **No second request here, and that was a bug.** `project_config` says
    // `sendVerificationEmailOnSignUp: false`, so this asked for a code on the
    // way to the verify screen — and the provider had already sent one, because
    // `requireEmailVerification` makes sign-up issue an OTP whatever that flag
    // says. Two codes arrived, the second invalidated the first, and a player
    // typing the one that landed first was told it was wrong.
    //
    // Observed on a device before it was reasoned about. The resend button is
    // still there for a code that never arrives; it just is not pressed for
    // everyone automatically.
    setState(() {
      _busy = false;
      _codeIssuedAt = DateTime.now();
      _trail.add(_Step.verify);
    });
  }

  Future<void> _requestCode({bool moveOn = false}) async {
    setState(() => _busy = true);
    final AuthResult<Accepted> sent = await widget.auth.sendVerificationCode(
      _email,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _problem = _explain(sent);
      if (_problem == null) {
        _codeIssuedAt = DateTime.now();
        if (moveOn) {
          _trail.add(_Step.verify);
        }
      }
    });
  }

  Future<void> _verify(String code) async {
    setState(() {
      _busy = true;
      _problem = null;
    });

    final AuthResult<AuthSession> verified = await widget.auth.verifyEmail(
      email: _email,
      code: code,
    );
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

    await _linkWith(verified.value);
  }

  Future<void> _signIn(String email, String password) async {
    setState(() {
      _busy = true;
      _problem = null;
      _email = email;
    });

    final AuthResult<AuthSession> session = await widget.auth.signIn(
      email: email,
      password: password,
    );
    if (!mounted) {
      return;
    }
    if (session is! AuthOk<AuthSession>) {
      setState(() {
        _busy = false;
        _problem = _explain(session) ?? 'No pudimos entrar con esos datos.';
      });
      return;
    }
    // **No code is asked for here.** `requireEmailVerification` is on, so the
    // provider hands out no session for an unverified address at all — a
    // session in hand means the address is already confirmed, and sending a
    // code would be sending one nobody needs.
    //
    // **The unverified account is a dead end, and it is not handled.** Somebody
    // who created an account and closed the app before typing the code gets a
    // refusal here with no way on, even though `sendVerificationCode` and
    // `_Step.verify` both exist. Routing to them needs the refusal's code
    // string, and nobody has enumerated the provider's codes — guessing at one
    // is what `_explain` refuses to do. It is a gap waiting on a measurement,
    // not an oversight.
    await _linkWith(session.value);
  }

  /// The last stretch both doors share: a session becomes the JWT the AkiMath
  /// server verifies, or the screen says why it did not.
  Future<void> _linkWith(AuthSession session) async {
    final AuthResult<String> token = await widget.auth.accessToken(session);
    if (!mounted) {
      return;
    }
    if (token is! AuthOk<String>) {
      setState(() {
        _busy = false;
        _problem =
            _explain(token) ?? 'La cuenta quedó lista pero no pudimos entrar.';
      });
      return;
    }

    setState(() => _busy = false);
    widget.onLinked(
      LinkedAccount(accessToken: token.value, ageBand: _band!, email: _email),
    );
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
    _Step.age => AgeGateScreen(
      today: widget.today,
      onResolved: _resolved,
      onBack: _back,
    ),
    _Step.consent => TutorConsentScreen(onBack: widget.onGaveUp),
    _Step.create => CreateAccountScreen(
      onSubmit: _create,
      busy: _busy,
      problem: _problem,
      onBack: _back,
      onSignInInstead: () => _goTo(_Step.signIn),
    ),
    _Step.signIn => SignInScreen(
      onSubmit: _signIn,
      busy: _busy,
      problem: _problem,
      onBack: _back,
      initialEmail: _email,
      onForgotPassword: (String email) {
        _email = email;
        _resetSent = false;
        _goTo(_Step.recover);
      },
    ),
    _Step.recover => RecoverPasswordScreen(
      onSubmit: _sendPasswordReset,
      busy: _busy,
      sent: _resetSent,
      onBack: _back,
      initialEmail: _email,
      problem: _problem,
    ),
    _Step.verify => VerifyEmailScreen(
      email: _email,
      codeIssuedAt: _codeIssuedAt,
      onSubmit: _verify,
      onResend: _requestCode,
      busy: _busy,
      problem: _problem,
      onBack: _back,
    ),
  };
}
