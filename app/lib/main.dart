import 'package:flutter/material.dart';

import 'design/theme.dart';
import 'features/onboarding/ui/first_run_gate.dart';
import 'features/shell/ui/root_scaffold.dart';

void main() {
  runApp(const AkiMathApp());
}

/// The application root.
///
/// `FirstRunGate` decides what a launch opens: the onboarding on a first run,
/// the home on every one after. It owns the flag, so nothing else has to ask.
///
/// Behind it, `RootScaffold` holds the two roots — the home and preferences —
/// and the bar between them. The home pushes a series as a **full-screen
/// session**, declared rule 1, so a series has no navigation affordance and the
/// only way out is its own control: the bar does not follow a player into a
/// round.
///
/// **The bar exists because a second root does**, and for no other reason.
/// `visibleTabs` returned nothing while `rootsPresentToday` named one tab and
/// began returning two the moment preferences was added to it. The rule never
/// changed; the map joins the same way at F5.
class AkiMathApp extends StatelessWidget {
  const AkiMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AkiMath',
      debugShowCheckedModeBanner: false,
      theme: AkiMathTheme.build(),
      home: const FirstRunGate(home: RootScaffold()),
    );
  }
  
}
