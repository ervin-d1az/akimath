import 'package:flutter/material.dart';

import '../../../design/tokens/tokens.dart';
import '../../account/policy/session.dart';
import '../../home/ui/home_route.dart';
import '../../preferences/ui/preferences_route.dart';
import '../../progress/ui/progress_route.dart';
import '../policy/visible_tabs.dart';
import 'nav_bar.dart';

/// The three roots and the bar between them.
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
  /// **Here rather than in a root**, because two of them need it: `Ajustes`
  /// signs in and `Avance` shows what the account holds. `IndexedStack` keeps
  /// both alive, so a session held by one would never reach the other.
  ///
  /// In memory only — where a token may be written down is its own decision.
  LinkedSession? _session;

  @override
  Widget build(BuildContext context) {
    final List<AppTab> tabs = visibleTabs(rootsPresentToday);
    final int index = tabs.indexOf(_current);

    return Scaffold(
      backgroundColor: BrandColors.cream,
      body: IndexedStack(
        index: index < 0 ? 0 : index,
        children: <Widget>[
          for (final AppTab tab in tabs) _rootFor(tab),
        ],
      ),
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavBar(
              tabs: tabs,
              current: _current,
              onSelect: (AppTab tab) => setState(() => _current = tab),
            ),
    );
  }

  Widget _rootFor(AppTab tab) => switch (tab) {
        AppTab.home => const HomeRoute(),
        AppTab.progress => ProgressRoute(session: _session),
        AppTab.profile => PreferencesRoute(
            session: _session,
            onSessionChanged: (LinkedSession? session) =>
                setState(() => _session = session),
          ),
        // No root yet, and `rootsPresentToday` does not name it — so
        // `visibleTabs` never hands it over. Exhaustive rather than defaulted,
        // so F5 is a compile error here instead of a blank tab.
        AppTab.skills => const SizedBox.shrink(),
      };
}
