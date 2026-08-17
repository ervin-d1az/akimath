import 'package:flutter/material.dart';

import 'design/theme.dart';
import 'features/round/ui/round_route.dart';
import 'features/shell/ui/app_shell.dart';

void main() {
  runApp(const AkiMathApp());
}

/// The application root.
///
/// The home is the round: the app can now be played. It replaces the character
/// sheet, which was the home only because the brand layer was the only thing
/// built. Real navigation arrives with `f2-app-shell`.
///
/// `RoundRoute` rather than `RoundScreen`: the route loads the bundled pack and
/// the screen plays it, so the screen holds no IO and stays testable by handing
/// it a list of items.
///
/// `AppShell` is the frame. It draws **no bottom navigation** — `visibleTabs`
/// returns nothing while one root exists, so the bar is absent by rule rather
/// than by omission, and the same rule draws it when the skill map lands at F5.
/// The round is the single root today; `f2-home-reduced` becomes it.
class AkiMathApp extends StatelessWidget {
  const AkiMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AkiMath',
      debugShowCheckedModeBanner: false,
      theme: AkiMathTheme.build(),
      home: const AppShell(child: RoundRoute()),
    );
  }
}
