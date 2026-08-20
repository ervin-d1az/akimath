import 'package:flutter/material.dart';

import 'dart:async';

import '../../../api/api_client.dart';
import '../../../api/me.dart';
import '../../../api/auth_client.dart';
import '../../../api/endpoints.dart';
import '../../auth/ui/auth_flow.dart';
import '../../states/policy/account_state.dart';
import '../../account/data/player_id_store.dart';
import '../../account/policy/session.dart';
import '../../shell/ui/app_shell.dart';
import '../../preferences/policy/erasure.dart';
import '../../preferences/ui/account_screen.dart';
import '../../preferences/ui/erase_account_route.dart';
import '../../preferences/ui/legend_screen.dart';
import '../../preferences/ui/settings_list_screen.dart';
import 'profile_screen.dart';

/// The profile root, and the stack it pushes.
///
/// **Renamed from `ProfileRoute` and moved, rather than rewritten.**
/// Declared rule 1 names the bar's homes as *inicio, mapa, progreso y perfil*;
/// the third root was Ajustes, which that rule does not name. Everything about
/// the account — linking on a session appearing, the sign-in flow, the erasure
/// — is unchanged and only re-parented; a review that finds logic moving inside
/// one of them has found something worth asking about (D6).
///
/// It owns the pushes because it owns the session and the token: `Cuenta`'s
/// erasure needs both, and a screen that took an `ApiClient` could not be
/// driven by a `testWidgets` — a real socket inside a fake-async zone hangs on
/// `!timersPending`, which is why every request here travels as a closure.
class ProfileRoute extends StatefulWidget {
  const ProfileRoute({
    super.key,
    this.session,
    this.onSessionChanged,
    this.now = DateTime.now,
    this.authBaseUrl = Endpoints.authBaseUrl,
    this.playerIds,
    this.link,
  });

  /// Where this device's own player id lives. Injected so a widget test never
  /// reaches a plugin.
  final PlayerIdStore? playerIds;

  /// Attaches this device's player to the account. A closure rather than an
  /// `ApiClient`, the same shape `EraseAccountRoute` takes and for the same
  /// reason: `testWidgets` runs in a fake-async zone and a real socket inside
  /// one hangs on `!timersPending`.
  final Future<LinkResult> Function({
    required String accessToken,
    required String playerId,
    required AgeBand ageBand,
  })? link;

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
  State<ProfileRoute> createState() => _ProfileRouteState();
}

class _ProfileRouteState extends State<ProfileRoute> {
  @override
  void initState() {
    super.initState();
    _linkIfNeeded(null);
  }

  @override
  void didUpdateWidget(ProfileRoute old) {
    super.didUpdateWidget(old);
    _linkIfNeeded(old.session);
  }

  /// Links whenever a session appears, rather than when a screen calls back.
  ///
  /// **The session is the trigger, not the sign-in.** A route that linked from
  /// the auth flow's callback would leave any other way of getting a session —
  /// a restored one, a second root — with an account and no player, which is
  /// exactly the state the app sat in before this existed.
  void _linkIfNeeded(LinkedSession? before) {
    final LinkedSession? session = widget.session;
    if (session == null || session.accessToken == before?.accessToken) {
      return;
    }
    unawaited(_link(session));
  }



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


  /// Attaches this device's player, then asks the server who that is.
  ///
  /// **Linking first, and on every sign-in.** An account with no player is the
  /// state the app used to sit in for ever — nothing called `POST /players/link`
  /// — so `GET /me` answered 404, and every other operation would have too.
  /// It is idempotent by nature (the row it would write is the row already
  /// there), so a returning device re-attaches rather than needing to know
  /// whether it linked before.
  ///
  /// **One round trip, because the link already answers with the profile.**
  /// `POST /players/link` returns the frozen `Me` — that *is* the server's
  /// word, so asking `GET /me` straight afterwards would be the same question
  /// twice. The lookup stays for the retry path, where a failed one can be
  /// asked again.
  Future<void> _link(LinkedSession session) async {
    setState(() => _accountState = AccountState.loading);

    final String playerId =
        await (widget.playerIds ?? const PrefsPlayerIdStore()).readOrMint();
    final LinkResult linked = await (widget.link ?? _linkOverASocket)(
      accessToken: session.accessToken,
      playerId: playerId,
      ageBand: session.ageBand,
    );
    if (!mounted) {
      return;
    }
    setState(() => _accountState = linkStateFor(linked));
  }

  Future<LinkResult> _linkOverASocket({
    required String accessToken,
    required String playerId,
    required AgeBand ageBand,
  }) async {
    final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
    try {
      return await api.linkPlayer(
        accessToken: accessToken,
        playerId: playerId,
        ageBand: ageBand,
        // The contract requires the header and the server ignores its value:
        // linking is idempotent by nature rather than by a replay store. The
        // player id is the one thing that is stable across this device's
        // retries and unique to it.
        idempotencyKey: 'link:$playerId',
      );
    } finally {
      api.close();
    }
  }

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
              ageBand: account.ageBand,
            ));
            Navigator.of(context).pop();
            // The linking follows from the session existing — see
            // `didUpdateWidget` — rather than from this callback, so a session
            // that arrives any other way is linked too.
          },
          onGaveUp: () {
            auth.close();
            Navigator.of(context).pop();
          },
        ),
      ),
    ));
  }

  /// Pushes a settings screen onto the tab's own navigator.
  ///
  /// **Not `fullScreenSession`.** That route exists to make a *session* — a
  /// round, a board — take the whole screen with no way out but finishing. The
  /// group badge over `4.1`–`4.7` says the opposite: *"Aquí sí va la barra
  /// inferior."* So these push under the bar, and the back control is a pop
  /// rather than a flag on the root.
  void _push(Widget Function(VoidCallback back) build) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (BuildContext pushed) =>
          build(() => Navigator.of(pushed).pop()),
    ));
  }

  void _openSettings() => _push(
        (VoidCallback back) => AppShell(
          child: SettingsListScreen(
            onBack: back,
            onOpenAccount: _openAccountDetail,
            onOpenLegend: () => _push(
              (VoidCallback back) => AppShell(child: LegendScreen(onBack: back)),
            ),
          ),
        ),
      );

  void _openAccountDetail() {
    final String? email = widget.session?.email;
    if (email == null) {
      return;
    }
    _push(
      (VoidCallback back) => AppShell(
        child: AccountScreen(
          onBack: back,
          email: email,
          // Only where a session exists that the request could travel on.
          // `erasureOffered` is the judgement; the token is the fact.
          onErase: erasureOffered(_accountState) ? _openEraseFlow : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: ProfileScreen(
        accountEmail: widget.session?.email,
        accountState: _accountState,
        onOpenSettings: _openSettings,
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
      ),
    );
  }
}
