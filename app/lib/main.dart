import 'package:flutter/material.dart';

import 'design/theme.dart';
import 'features/home/ui/home_route.dart';

void main() {
  runApp(const AkiMathApp());
}

/// The application root.
///
/// The home is the round: the app can now be played. It replaces the character
/// sheet, which was the home only because the brand layer was the only thing
/// built. Real navigation arrives with `f2-app-shell`.
///
/// `HomeRoute` is the single tab root: it loads the bundled pack, shows the
/// home, and pushes the series as a **full-screen session** — declared rule 1,
/// so a series has no navigation affordance and the only way out is its own
/// control.
///
/// The frame is `AppShell`, which draws **no bottom navigation**: `visibleTabs`
/// returns nothing while one root exists, so the bar is absent by rule rather
/// than by omission, and the same rule draws it when the map lands at F5.
class AkiMathApp extends StatelessWidget {
  const AkiMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AkiMath',
      debugShowCheckedModeBanner: false,
      theme: AkiMathTheme.build(),
      home: const HomeRoute(),
    );
  }
}
