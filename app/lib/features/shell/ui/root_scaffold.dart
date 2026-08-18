import 'package:flutter/material.dart';

import '../../../design/tokens/tokens.dart';
import '../../home/ui/home_route.dart';
import '../../preferences/ui/preferences_route.dart';
import '../policy/visible_tabs.dart';
import 'nav_bar.dart';

/// The two roots and the bar between them.
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
        AppTab.profile => const PreferencesRoute(),
        // Neither has a root yet, and `rootsPresentToday` does not name them —
        // so `visibleTabs` never hands either one over. Exhaustive rather than
        // defaulted, so F5 is a compile error here instead of a blank tab.
        AppTab.skills || AppTab.progress => const SizedBox.shrink(),
      };
}
