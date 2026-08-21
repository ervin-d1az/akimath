import 'dart:async';

import 'package:flutter/material.dart';

import '../../../api/auth_client.dart';
import '../../../api/endpoints.dart';
import '../../../design/tokens/tokens.dart';
import '../../account/data/session_store.dart';
import '../../account/policy/session.dart';
import '../../account/policy/session_restore.dart';
import '../../home/ui/home_route.dart';
import '../../map/ui/map_route.dart';
import '../../profile/ui/profile_route.dart';
import '../policy/visible_tabs.dart';
import 'nav_bar.dart';
import 'tab_stack.dart';

/// The roots, the bar between them, and the account they share.
///
/// Each root keeps its own state across a switch — an `IndexedStack` rather
/// than a rebuild — because a player who checks their streak and comes back
/// should not find the home re-reading its pack and flashing a skeleton.
///
/// **It owns the session because two roots have to agree about one**, and it
/// owns the *storing* of the session for the same reason: the shell is the one
/// place that sees a sign-in, a sign-out and a launch, so the credential on
/// disk and the session in memory cannot drift apart.
class RootScaffold extends StatefulWidget {
  const RootScaffold({
    super.key,
    this.sessions = const PrefsSessionStore(),
    this.deriveToken,
    this.authBaseUrl = Endpoints.authBaseUrl,
  });

  /// Where Neon Auth is, defaulting to the build's own `--dart-define`.
  ///
  /// **A parameter and not a direct read of the constant**, the same shape
  /// `ProfileRoute.authBaseUrl` takes and for the reason recorded there: a
  /// compile-time constant is one no test can vary, and "the build was
  /// configured" is exactly the claim worth checking. It was asserted on that
  /// route once and was false.
  final String authBaseUrl;

  /// Where being signed in is kept between launches. Injected so a widget test
  /// never reaches a plugin.
  final SessionStore sessions;

  /// Asks the provider for an access token from a stored credential.
  ///
  /// A closure rather than an `AuthApi`, the shape `EraseAccountRoute.erase`
  /// and `ProfileRoute.whoAmI` take and for the same reason: `testWidgets` runs
  /// in a fake-async zone and a real socket inside one hangs on
  /// `!timersPending`. Null in the app, where the shell opens an [AuthClient]
  /// of its own and closes it again.
  final Future<AuthResult<String>> Function(AuthSession session)? deriveToken;

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  AppTab _current = AppTab.home;

  /// The account this device is signed in to.
  ///
  /// **Here rather than in a root**, because it outlives any one of them and
  /// the next root to need it should not have to ask the profile. `IndexedStack`
  /// keeps every root alive, so a session held inside one would never reach
  /// another.
  ///
  /// It starts null on every launch and a stored credential fills it in a frame
  /// or two later — [_restoreTheStoredSession] — so a root reading it once at
  /// construction reads *signed out* and never hears otherwise. That is
  /// PROC-13's territory and `TabStack` is what makes the later value arrive.
  LinkedSession? _session;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreTheStoredSession());
  }

  /// Comes up signed in where the device has a credential the provider honours.
  ///
  /// **The token is derived, never stored.** A Better Auth access token is
  /// minted per request and expires in minutes; the durable half is the
  /// provider's session cookie, so a launch trades the cookie for a fresh token
  /// rather than reading a stale one off disk.
  ///
  /// Nothing here waits on the network before the app is usable: the shell
  /// builds signed out and the session arrives when it arrives, so a player
  /// with no signal opens the app at the same speed as anyone else.
  Future<void> _restoreTheStoredSession() async {
    final StoredSession? stored = await widget.sessions.read();
    if (stored == null || !mounted) {
      return;
    }
    final AuthResult<String> answer = await _askForAToken(stored.provider);
    if (!mounted) {
      return;
    }
    switch (sessionRestore(stored: stored, providerAnswer: answer)) {
      case SessionRestored(session: final LinkedSession restored):
        setState(() => _session = restored);
      case SessionForgotten():
        await widget.sessions.forget();
      case SessionKept():
        // Offline, or a provider having a bad minute. The credential stays and
        // the app comes up signed out for this launch only — deleting it here
        // is the failure `sessionRestore` exists to prevent.
        break;
    }
  }

  /// Trades the stored credential for a token, or says it could not ask.
  ///
  /// **A build with no provider configured fails closed**, and it has to be
  /// said out loud because the open version is silently destructive.
  /// `Endpoints.authBaseUrl` is a `String.fromEnvironment` and is **empty in
  /// any build without the `--dart-define`** — every plain `flutter run`, and
  /// every test. `Uri.parse('')` is relative, and what happens next is not a
  /// clean failure: measured in `session_survives_a_relaunch_test.dart`, the
  /// answer came back as a **400**, which `AuthClient` maps to `AuthRefused`,
  /// which `sessionRestore` reads as *the provider has disowned this
  /// credential* — and the launch **deleted** a credential it had never
  /// managed to ask about. On a real device with no `HttpOverrides` the same
  /// call throws `ArgumentError` instead, an `Error` that
  /// `AuthClient._send`'s `on Exception` does not catch, so the restore dies
  /// inside an `unawaited` future with nothing said.
  ///
  /// Unreachable is the honest answer: nothing was asked, so nothing was
  /// learned, so the credential keeps.
  Future<AuthResult<String>> _askForAToken(AuthSession session) async {
    final Future<AuthResult<String>> Function(AuthSession)? injected =
        widget.deriveToken;
    if (injected != null) {
      return injected(session);
    }
    if (widget.authBaseUrl.isEmpty) {
      debugPrint('session: NEON_AUTH_BASE_URL is not set in this build, so the '
          'stored credential could not be checked; keeping it');
      return const AuthUnreachable<String>(
        'NEON_AUTH_BASE_URL is not set in this build',
      );
    }
    final AuthClient auth = AuthClient(baseUrl: Uri.parse(widget.authBaseUrl));
    try {
      return await auth.accessToken(session);
    } finally {
      auth.close();
    }
  }

  /// Makes the store agree with the session the shell holds.
  ///
  /// **One rule for all three callers, because all three want the same thing.**
  /// `onSessionChanged(null)` reaches here from a manual `Cerrar sesión` and
  /// from a successful `DELETE /me`, and cannot tell them apart — the callback
  /// carries no reason. It does not have to: a sign-out must leave nothing
  /// behind because the player asked, and an erasure must leave nothing behind
  /// because the account is gone. The day a third caller nulls the session for
  /// a reason that wants the credential *kept*, this callback needs that reason
  /// and this method needs to read it.
  ///
  /// **A session arriving with no credential deletes what was there**, rather
  /// than leaving it. Anything else would let the next launch restore an
  /// account this device is no longer signed in to — possibly somebody else's.
  Future<void> _holdAndRemember(LinkedSession? session) async {
    setState(() => _session = session);
    final StoredSession? storable = session?.storable;
    if (storable == null) {
      await widget.sessions.forget();
      return;
    }
    await widget.sessions.write(storable);
  }

  /// One navigator per tab, so a pushed screen lands **under** the bar.
  ///
  /// The settings screens sit above the profile root and the design says the
  /// bar stays: *"Aquí sí va la barra inferior."* A push onto the app's root
  /// navigator covers the whole `Scaffold`, which is what the app did until a
  /// device caught it.
  ///
  /// Every tab gets one, including the two that push nothing today — a wrapper
  /// applied only where it is needed now is one the next root will be missing.
  final Map<AppTab, GlobalKey<NavigatorState>> _stacks =
      <AppTab, GlobalKey<NavigatorState>>{
    for (final AppTab tab in AppTab.values) tab: GlobalKey<NavigatorState>(),
  };

  @override
  Widget build(BuildContext context) {
    final List<AppTab> tabs = visibleTabs(rootsPresentToday);
    final int index = tabs.indexOf(_current);

    return PopScope(
      // **The tab's stack answers a back press first.** Without this the first
      // press leaves the app, discarding a stack the player can see — which
      // reads as a crash rather than as navigation.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        // **The app's own navigator, captured before the await.** Reaching for
        // it through `context` afterwards is the gap the analyzer names, and
        // the guard that would satisfy it — `mounted` — is about this State and
        // not about that context.
        final NavigatorState app = Navigator.of(context);
        final bool handled = await TabStack.popTab(_stacks[_current]!);
        if (!handled) {
          app.pop();
        }
      },
      child: Scaffold(
        backgroundColor: BrandColors.cream,
        body: IndexedStack(
          index: index < 0 ? 0 : index,
          children: <Widget>[
            for (final AppTab tab in tabs)
              TabStack(navigatorKey: _stacks[tab], child: _rootFor(tab)),
          ],
        ),
        bottomNavigationBar: tabs.length < 2
            ? null
            : NavBar(
                tabs: tabs,
                current: _current,
                onSelect: (AppTab tab) => setState(() => _current = tab),
              ),
      ),
    );
  }

  Widget _rootFor(AppTab tab) => switch (tab) {
        // **The home is handed the session too.** It is the only root that
        // produces an answer, and an answer is only worth remembering when
        // there is somewhere to send it — unlinked play is entirely offline
        // (ADR 0002).
        // **It is told when it is being looked at too.** Mapa starts a practice
        // run against the same day log the home reads, and the home pushed
        // none of it — so without this the streak on Inicio is whatever it was
        // when the player last left it (PROC-13).
        AppTab.home => HomeRoute(
            visibility: _current == AppTab.home
                ? RootVisibility.showing
                : RootVisibility.behind,
            session: _session,
          ),
        // **It is told when it is being looked at.** Every root stays mounted,
        // so the profile's `initState` runs once per launch — and it reads
        // figures the home writes while it is behind. Without this it showed
        // `RACHA 0` on the same screenful of app that had just drawn `RACHA 1`.
        AppTab.profile => ProfileRoute(
            visibility: _current == AppTab.profile
                ? RootVisibility.showing
                : RootVisibility.behind,
            session: _session,
            onSessionChanged: (LinkedSession? session) =>
                unawaited(_holdAndRemember(session)),
          ),
        // **Told when it is being looked at, for the reason the profile is.**
        // The map's figures come from the series cursor, which a series played
        // on Inicio advances while this root sits behind — so without this it
        // draws launch-time percentages for ever (PROC-13).
        AppTab.skills => MapRoute(
            visibility: _current == AppTab.skills
                ? RootVisibility.showing
                : RootVisibility.behind,
          ),
        // **The last tab with no root**, and `rootsPresentToday` says so — so
        // `visibleTabs` never hands it over. Exhaustive rather than defaulted,
        // so a root arriving is a compile error here instead of a blank tab.
        //
        // `progress` sits here for the same reason it stays in the enum: the
        // design names it a home and nobody has drawn one. What ours held is
        // on the profile now.
        AppTab.progress => const SizedBox.shrink(),
      };
}
