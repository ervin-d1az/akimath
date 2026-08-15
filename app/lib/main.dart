import 'package:flutter/material.dart';

import 'design/theme.dart';
import 'features/brand_gallery/brand_gallery_screen.dart';

void main() {
  runApp(const AmbysMathApp());
}

/// The application root.
///
/// The only thing built so far is the brand layer, so the home screen is the
/// brand gallery. It gets replaced by the real navigation the moment there is
/// something to navigate to.
class AmbysMathApp extends StatelessWidget {
  const AmbysMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AmbysMath',
      debugShowCheckedModeBanner: false,
      theme: AmbysMathTheme.build(),
      home: const BrandGalleryScreen(),
    );
  }
}
