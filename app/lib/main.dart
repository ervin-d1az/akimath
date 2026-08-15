import 'package:flutter/material.dart';

import 'design/theme.dart';
import 'features/character_sheet/character_sheet_screen.dart';

void main() {
  runApp(const AkiMathApp());
}

/// The application root.
///
/// The only thing built so far is the brand layer, so the home screen is Aki's
/// character sheet. It gets replaced by the real navigation the moment there is
/// something to navigate to.
class AkiMathApp extends StatelessWidget {
  const AkiMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AkiMath',
      debugShowCheckedModeBanner: false,
      theme: AkiMathTheme.build(),
      home: const CharacterSheetScreen(),
    );
  }
}
