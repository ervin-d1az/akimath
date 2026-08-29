import 'package:flutter/widgets.dart';

import '../../../api/auth_client.dart';
import '../../../api/me.dart';
import '../../../api/me_result.dart';
import '../policy/age_gate.dart';
import 'adults_only_screen.dart';
import 'age_gate_screen.dart';
import 'create_account_screen.dart';
import 'new_password_screen.dart';
import 'recover_password_screen.dart';
import 'sign_in_screen.dart';
import 'verify_email_screen.dart';

/// What the flow produced: an account, verified, with the token the AkiMath
/// server verifies and the band the link request has to carry.
@immutable
class LinkedAccount {
  const LinkedAccount({
    required this.accessToken,
    required this.ageBand,
    required this.email,
    required this.provider,
  });

  final String accessToken;
  final AgeBand ageBand;
  final String email;

  /// The credential the token was derived from — what survives a relaunch.
  ///
  /// An access token is minted per request and expires in minutes, so it is
  /// the wrong thing to keep. This is what a launch re-derives one from.
  final AuthSession provider;
}

/// Which door the flow opens on.
///
/// **Two, because two things bring a player here.** Making an account and
/// coming back to one are different errands, and routing both through the
/// sign-up form made the second one four screens long — reported from a device
/// as *"it's hard to find"*.
enum AuthEntry {
  /// `1.3 ¿Cuándo naciste?` first, then `Crear cuenta`.
  createAccount,

  /// Straight to `Iniciar sesión`.
  signIn,
}

/// The account flow, the gate first where a gate is what is needed
/// (`req-no-account-without-a-declaration`).
///
/// **The gate is structural, not a check.** No path reaches
/// `CreateAccountScreen` without an eligible band, because the field holding it
/// is what selects the screen, and nothing below the threshold gets past
/// `AdultsOnlyScreen`.
///
/// **Signing in resolves a band a second honest way.** `LinkedAccount.ageBand`
/// is required because `players.age_band` is what the device declared, and for
/// a returning player the server already holds it: `GET /me` answers that
/// column. So [AuthEntry.signIn] asks the server rather than the player, and
/// falls back to the gate in the one case where the server has nothing to say —
/// an account with no player, which `DELETE /me` leaves behind because it
/// erases the player and not the Neon Auth account. **No band is ever
/// defaulted**; a `?? adult` is not a decision this app is allowed to make.
///
/// **Both sources are judged, and by the same function.** ADR 0004 makes the
/// product adults-only, so a band below the threshold ends the flow whether it
/// came off the gate or off the server — `_refuse` is the one place either
/// reaches, and `AgeGate.next` is the one thing that decides.
///
/// The order is the provider's: sign up, ask for a code (the provider sends none
/// on sign-up), verify, then `GET /token` for the JWT. Each step's failure is a
/// message on the screen it came from rather than a thrown exception.
class AuthFlow extends StatefulWidget {
  const AuthFlow({
    super.key,
    required this.auth,
    required this.whoAmI,
    required this.callbackUrl,
    required this.today,
    required this.onLinked,
    required this.onGaveUp,
    this.entry = AuthEntry.createAccount,
    this.resetToken,
  });

  final AuthApi auth;

  /// Asks the AkiMath server who a token belongs to.
  ///
  /// **A closure and not an `ApiClient`**, the same shape every other request
  /// this corner of the app makes: a `testWidgets` runs in a fake-async zone and
  /// a real socket inside one hangs on `!timersPending`.
  ///
  /// Required rather than nullable even though the create path never calls it.
  /// A parameter that must be non-null in one mode and may be null in another
  /// is a null check waiting to be reached.
  final Future<MeResult> Function(String accessToken) whoAmI;

  /// Which errand the player is on.
  final AuthEntry entry;

  /// Absolute, or the provider answers `MISSING_ORIGIN` — a mobile app has no
  /// origin to send.
  final String callbackUrl;
  final DateTime today;
  final void Function(LinkedAccount account) onLinked;
  final VoidCallback onGaveUp;

  /// The token out of a password-reset email. Non-null opens the flow on `1.5`
  /// instead of the gate — resetting a password is not creating an account, so
  /// there is no band to resolve.
  ///
  /// **Nothing passes one today.** The token only ever arrives inside the
  /// emailed link, and receiving that needs a URL scheme registered in
  /// `AndroidManifest.xml` and `Info.plist` and added to the provider's
  /// `trusted_origins` — none of which exists. This is the seam that opens the
  /// day it does, and it is what lets the screen be driven for real now rather
  /// than sit unreachable.
  final String? resetToken;

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

enum _Step { age, refused, create, signIn, recover, newPassword, verify }

class _AuthFlowState extends State<AuthFlow> {
  /// The steps behind the one on screen, oldest first.
  ///
  /// **A stack rather than a predecessor per step**, because more than one
  /// screen leads to the same place and "where you came from" is the only
  /// answer a back control can give that is never surprising.
  late final List<_Step> _trail = <_Step>[_opensOn()];

  /// The first screen, decided once. A reset token wins over the entry, because
  /// arriving through an emailed link is not an errand the profile chose.
  _Step _opensOn() {
    if (widget.resetToken != null) {
      return _Step.newPassword;
    }
    return switch (widget.entry) {
      AuthEntry.createAccount => _Step.age,
      AuthEntry.signIn => _Step.signIn,
    };
  }

  _Step get _step => _trail.last;

  AgeBand? _band;

  /// A JWT in hand with no band to link it under.
  ///
  /// **Only the sign-in door can produce one.** It is held for exactly as long
  /// as the gate is on screen, and it is what tells [_resolved] to finish
  /// rather than open the sign-up form.
  String? _pendingToken;

  /// The cookie behind [_pendingToken], held for the same stretch.
  AuthSession? _pendingProvider;
  String _email = '';
  String? _problem;
  bool _busy = false;

  /// Whether the provider has accepted a reset request. Set from its answer and
  /// cleared on the way into `1.4`, so a second visit does not open on the
  /// confirmation the first one earned.
  bool _resetSent = false;

  /// Whether the provider has accepted a new password.
  bool _passwordSaved = false;
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

  void _resolved(AgeBand band, AgeGateOutcome outcome) {
    if (outcome == AgeGateOutcome.refused) {
      _refuse();
      return;
    }

    final String? signedIn = _pendingToken;
    setState(() {
      _band = band;
      _problem = null;
      if (signedIn == null) {
        _trail.add(_Step.create);
      }
    });
    final AuthSession? held = _pendingProvider;
    if (signedIn != null && held != null) {
      // The gate was the last thing missing: the account is already signed in
      // and this is the band its link will carry.
      _handOver(signedIn, band, held);
    }
  }

  /// The end of the flow for anyone the product is not for (ADR 0004).
  ///
  /// **One place, because there are two sources of a band.** The gate resolves
  /// one from a date, and the sign-in door reads one off `GET /me`; both arrive
  /// here through `AgeGate.next`, so the two cannot answer the same fact
  /// differently.
  ///
  /// **A session in hand is dropped.** Somebody who signed in and turns out to
  /// be a minor does not leave this flow with a token — the provider granted
  /// one and we cannot withdraw it, but nothing here carries it onward, so no
  /// link request is made and the shell never learns of an account.
  ///
  /// **The refusal replaces the trail rather than extending it**, so
  /// `req-no-account-without-a-declaration`'s *no path from here reaches the
  /// form* is true by construction: there is nothing behind it to go back to,
  /// and the one control it draws leaves the flow.
  void _refuse() {
    setState(() {
      _busy = false;
      _band = null;
      _problem = null;
      _pendingToken = null;
      _pendingProvider = null;
      _trail
        ..clear()
        ..add(_Step.refused);
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

  Future<void> _savePassword(String password) async {
    setState(() {
      _busy = true;
      _problem = null;
    });

    final AuthResult<Accepted> saved = await widget.auth.resetPassword(
      token: widget.resetToken!,
      newPassword: password,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _problem = _explain(saved);
      // A reset hands back no session, so this is as far as it goes: the
      // player signs in next, which is what the screen offers.
      _passwordSaved = _problem == null;
    });
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

    final AgeBand? resolved = _band;
    if (resolved == null) {
      await _bandTheServerAlreadyHas(token.value, session);
      return;
    }
    setState(() => _busy = false);
    _handOver(token.value, resolved, session);
  }

  /// The sign-in door's band, asked of the one place that knows it.
  ///
  /// `GET /me` answers `players.age_band` itself, so a returning player is
  /// judged on the band the server already holds — read, never guessed. The
  /// gate is reached only when there is no player to read it off.
  ///
  /// **The band is judged here too, by the same function.** This is the second
  /// source of a band in the app, and before ADR 0004 it was the only one that
  /// could produce a minor's without the gate having been asked. A `13_17` row
  /// is reachable rather than hypothetical: that band reached the account form
  /// until this change, and the frozen `CHECK` still permits it.
  Future<void> _bandTheServerAlreadyHas(
    String accessToken,
    AuthSession provider,
  ) async {
    final MeResult who = await widget.whoAmI(accessToken);
    if (!mounted) {
      return;
    }
    switch (who) {
      case MeFound(:final Me me):
        if (AgeGate.next(me.ageBand) == AgeGateOutcome.refused) {
          _refuse();
          return;
        }
        setState(() => _busy = false);
        _handOver(accessToken, me.ageBand, provider);
      case MeNoPlayer():
        // `DELETE /me` leaves the account standing, so this is where an erased
        // player comes back to. A link needs a band and nothing on the server
        // has one, which makes this the first moment the question is
        // unavoidable — and the last moment it is honest to ask it.
        setState(() {
          _busy = false;
          _pendingToken = accessToken;
          _pendingProvider = provider;
          _trail.add(_Step.age);
        });
      case MeRejected():
        setState(() {
          _busy = false;
          _problem = 'Entraste, pero no pudimos abrir tu perfil.';
        });
      case MeFailed():
        setState(() {
          _busy = false;
          _problem = 'Algo falló de nuestro lado. Inténtalo otra vez.';
        });
      case MeUnreachable():
        setState(() {
          _busy = false;
          _problem = 'Sin conexión. Revisa tu internet.';
        });
    }
  }

  void _handOver(String accessToken, AgeBand band, AuthSession provider) =>
      widget.onLinked(
        LinkedAccount(
          accessToken: accessToken,
          ageBand: band,
          email: _email,
          provider: provider,
        ),
      );

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
    _Step.refused => AdultsOnlyScreen(onBack: widget.onGaveUp),
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
    _Step.newPassword => NewPasswordScreen(
      onSubmit: _savePassword,
      busy: _busy,
      saved: _passwordSaved,
      onBack: _back,
      onSignIn: () => _goTo(_Step.signIn),
      problem: _problem,
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
