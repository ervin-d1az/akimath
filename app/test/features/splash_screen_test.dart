import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/brand/wordmark.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/loading_dots.dart';
import 'package:akimath_app/features/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, SplashVariant variant) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AkiMathTheme.build(),
        home: SplashScreen(variant: variant),
      ),
    );
  }

  testWidgets('the cream splash stands Aki over the wordmark',
      (WidgetTester tester) async {
    await pump(tester, SplashVariant.cream);

    expect(find.byType(Aki), findsOneWidget);
    expect(find.byType(AkiFace), findsNothing);
    expect(find.byType(AkiMathWordmark), findsOneWidget);
    expect(find.byType(BrandDescriptor), findsOneWidget);
    expect(find.byType(LoadingDots), findsOneWidget);

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, BrandColors.cream);
  });

  testWidgets('the green splash swaps the full body for the face tile',
      (WidgetTester tester) async {
    await pump(tester, SplashVariant.brandGreen);

    expect(find.byType(Aki), findsNothing);
    expect(find.byType(AkiFace), findsOneWidget);

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, BrandColors.green);

    final AkiMathWordmark wordmark =
        tester.widget<AkiMathWordmark>(find.byType(AkiMathWordmark));
    expect(wordmark.tone, WordmarkTone.onBrandGreen);
  });

  testWidgets('shows three loading dots and no spinner',
      (WidgetTester tester) async {
    await pump(tester, SplashVariant.cream);

    expect(LoadingDots.colors, hasLength(3));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Aki stands at the width the design states',
      (WidgetTester tester) async {
    await pump(tester, SplashVariant.cream);

    expect(tester.widget<Aki>(find.byType(Aki)).width, 210);
  });

  /// The gaps of the splash's own column.
  ///
  /// Read from the column's children rather than from every [SizedBox] in the
  /// tree: `Aki` builds one of its own to hold the artwork, and a tree-wide
  /// sweep would measure that instead.
  List<double?> gapsOf(WidgetTester tester) {
    final Column column = tester.widget<Column>(find.byType(Column));
    return column.children
        .whereType<SizedBox>()
        .map((SizedBox gap) => gap.height)
        .toList();
  }

  for (final SplashVariant variant in SplashVariant.values) {
    testWidgets('the ${variant.name} splash spaces its column uniformly',
        (WidgetTester tester) async {
      await pump(tester, variant);

      // The design measures 26/26/26. The file reached 28/28/36 by arithmetic
      // on the spacing scale, which read as three deliberate values.
      expect(gapsOf(tester), <double>[26, 26, 26]);
    });
  }

  testWidgets('the face tile is outlined at the standard stroke',
      (WidgetTester tester) async {
    await pump(tester, SplashVariant.brandGreen);

    final Container tile = tester.widget<Container>(
      find.ancestor(
        of: find.byType(AkiFace),
        matching: find.byType(Container),
      ),
    );
    final BoxDecoration decoration = tile.decoration! as BoxDecoration;

    // The 4 that stood here had no reason next to it; BRD-2c says outright
    // that it was not pre-blessed. The tile's 60px radius is the one
    // deliberate departure on this screen and it carries its reason.
    expect(decoration.border!.top.width, BrandShape.borderWidth);
    expect(decoration.borderRadius, BorderRadius.circular(60));
  });
}
