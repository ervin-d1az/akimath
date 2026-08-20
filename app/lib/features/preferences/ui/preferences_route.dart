import 'package:flutter/material.dart';

import 'dart:async';

import '../../../api/api_client.dart';
import '../../../api/auth_client.dart';
import '../../../api/endpoints.dart';
import '../../auth/ui/auth_flow.dart';
import '../../states/policy/account_state.dart';
import '../../account/policy/session.dart';
import '../../shell/ui/app_shell.dart';
import '../policy/erasure.dart';
import 'erase_account_route.dart';
import 'preferences_screen.dart';

/// Reads the day log and hands the screen two numbers.
///
/// The adapter half, and it is small on purpose: everything this root shows is
/// already computed by policies the home uses, so there is nothing here to get
/// wrong except the reading.
class PreferencesRoute extends StatefulWidget {
  const PreferencesRoute({
    super.key,
    this.session,
    this.onSessionChanged,
    this.now = DateTime.now,
    this.authBaseUrl = Endpoints.authBaseUrl,
  });

  /// The account this device is signed in to, owned by the shell.
  ///
  /// **Lifted out of this route when `Avance` arrived.** Two roots have to
  /// agree about whether there is an account — one signs in and the other shows
  /// what the account holds — and the only place that can hold that is their
  /// common ancestor.
  final LinkedSession? session;

  /// Reports a sign-in, or a sign-out when the account is erased.
  final ValueChanged<LinkedSession?>? onSessionChanged;

  /// Where Neon Auth is, defaulting to the build's own `--dart-define`.
  ///
  /// **A parameter and not a direct read of the constant**, because a
  /// compile-time constant is one no test can vary — and "the door appears when
  /// the build was configured" is exactly the claim worth checking. It was
  /// asserted here once and was false: the first simulator build reused a
  /// cached kernel, the defines never landed, and the row silently did not
  /// render.
  final String authBaseUrl;

  /// Injected, so the streak can be tested by handing it a date.
  final DateTime Function() now;

  @override
  State<PreferencesRoute> createState() => _PreferencesRouteState();
}

class _PreferencesRouteState extends State<PreferencesRoute> {


  /// What the AkiMath server said when asked who this token belongs to.
  ///
  /// **The account is only half the chain.** A verified Neon Auth account with
  /// a JWT proves the provider works; it proves nothing about whether our own
  /// server accepts that token. So the flow's last act is to ask.
  ///
  /// Held as a state rather than a sentence: the copy, the hue and whether
  /// there is a retry are `features/states/`, and a screen that assembled them
  /// inline would grow a branch per case and miss the one nobody writes —
  /// loading, which is not a `MeResult` at all.
  AccountState _accountState = AccountState.none;


  Future<void> _askWhoIAm(String accessToken) async {
    setState(() => _accountState = AccountState.loading);

    final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
    final MeResult result = await api.getMe(accessToken);
    api.close();
    if (!mounted) {
      return;
    }
    setState(() => _accountState = accountStateFor(result));
  }

  /// The one destructive act, and it is a full screen rather than a dialog.
  ///
  /// The question needs a sentence about what survives the call — the address
  /// stays registered with the identity provider, which is not ours to delete —
  /// and that does not fit in an alert. It is also not a surface this app draws.
  void _openEraseFlow() {
    final String token = widget.session!.accessToken;
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext _) => AppShell(
        child: EraseAccountRoute(
          erase: () async {
            final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
            try {
              return await api.eraseMe(token);
            } finally {
              api.close();
            }
          },
          onClose: (bool erased) {
            Navigator.of(context).pop();
            if (!erased || !mounted) {
              return;
            }
            // Forgotten here as well as there. Leaving the address on screen
            // after the row is gone would be the app disagreeing with the
            // server about whether this device is linked.
            setState(() => _accountState = AccountState.none);
            widget.onSessionChanged?.call(null);
          },
        ),
      ),
    ));
  }

  void _openAccountFlow() {
    final AuthClient auth = AuthClient(baseUrl: Uri.parse(widget.authBaseUrl));
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext _) => AppShell(
        child: AuthFlow(
          auth: auth,
          // The provider's own origin: the only one it trusts while
          // `trusted_origins` is empty. See `Endpoints.callbackUrl`.
          callbackUrl: widget.authBaseUrl,
          today: widget.now(),
          onLinked: (LinkedAccount account) {
            auth.close();
            if (!mounted) {
              return;
            }
            widget.onSessionChanged?.call(LinkedSession(
              email: account.email,
              accessToken: account.accessToken,
            ));
            Navigator.of(context).pop();
            // The half the provider cannot vouch for: does *our* server accept
            // the token it just issued?
            unawaited(_askWhoIAm(account.accessToken));
          },
          onGaveUp: () {
            auth.close();
            Navigator.of(context).pop();
          },
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: PreferencesScreen(
        // Zero before the store answers, and zero for a player who has never
        // played — the same number, which is why nothing here waits on a
        // skeleton. There is no state in which this screen has nothing to say.
        accountEmail: widget.session?.email,
        accountState: _accountState,
        // Only offered where retrying could change the answer. A retry on a
        // refused session would fetch the same refusal.
        onRetryAccount: _accountState == AccountState.offline ||
                _accountState == AccountState.serverError
            ? () => unawaited(_askWhoIAm(widget.session!.accessToken))
            : null,
        // Absent rather than broken when the build was given no endpoints.
        onCreateAccount: widget.authBaseUrl.isNotEmpty && widget.session == null
            ? _openAccountFlow
            : null,
        // Only where a session exists that the request could travel on.
        // `erasureOffered` is the judgement; the token is the fact.
        onEraseData: erasureOffered(_accountState) && widget.session != null
            ? _openEraseFlow
            : null,
      ),
    );
  }
}
