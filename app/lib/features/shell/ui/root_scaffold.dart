import 'package:flutter/material.dart';

import '../../../design/tokens/tokens.dart';
import '../../account/policy/session.dart';
import '../../home/ui/home_route.dart';
import '../../map/ui/map_route.dart';
import '../../profile/ui/profile_route.dart';
import '../policy/visible_tabs.dart';
import 'nav_bar.dart';
import 'tab_stack.dart';

/// The roots and the bar between them.
///
/// It holds which root is showing and nothing else. Each root keeps its own
/// state across a switch — an `IndexedStack` rather than a rebuild — because a
/// player who checks their streak and comes back should not find the home
/// re-reading its pack and flashing a skeleton.
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  AppTab _current = AppTab.home;

  /// The account this device is signed in to, for as long as the app is open.
  ///
  /// **Here rather than in a root**, because it outlives any one of them and
  /// the next root to need it should not have to ask the profile. `IndexedStack`
  /// keeps every root alive, so a session held inside one would never reach
  /// another.
  ///
  /// In memory only — where a token may be written down is its own decision.
  LinkedSession? _session;

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
        AppTab.home => HomeRoute(session: _session),
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
                setState(() => _session = session),
          ),
        AppTab.skills => const MapRoute(),
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
