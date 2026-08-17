import 'package:flutter/material.dart';

import 'design/theme.dart';
import 'features/round/ui/round_screen.dart';

void main() {
  runApp(const AkiMathApp());
}

/// The application root.
///
/// The home is the round: the app can now be played. It replaces the character
/// sheet, which was the home only because the brand layer was the only thing
/// built. Real navigation arrives with `f2-app-shell`.
class AkiMathApp extends StatelessWidget {
  const AkiMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AkiMath',
      debugShowCheckedModeBanner: false,
      theme: AkiMathTheme.build(),
      home: const RoundScreen(),
    );
  }
}
