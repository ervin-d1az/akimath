import 'package:ambysmath_app/design/brand/amby.dart';
import 'package:ambysmath_app/design/brand/wordmark.dart';
import 'package:ambysmath_app/design/theme.dart';
import 'package:ambysmath_app/design/tokens/tokens.dart';
import 'package:ambysmath_app/design/widgets/loading_dots.dart';
import 'package:ambysmath_app/features/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, SplashVariant variant) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AmbysMathTheme.build(),
        home: SplashScreen(variant: variant),
      ),
    );
  }

  testWidgets('the cream splash stands Amby over the wordmark',
      (WidgetTester tester) async {
    await pump(tester, SplashVariant.cream);

    expect(find.byType(Amby), findsOneWidget);
    expect(find.byType(AmbyFace), findsNothing);
    expect(find.byType(AmbysMathWordmark), findsOneWidget);
    expect(find.byType(BrandDescriptor), findsOneWidget);
    expect(find.byType(LoadingDots), findsOneWidget);

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, BrandColors.cream);
  });

  testWidgets('the green splash swaps the full body for the face tile',
      (WidgetTester tester) async {
    await pump(tester, SplashVariant.brandGreen);

    expect(find.byType(Amby), findsNothing);
    expect(find.byType(AmbyFace), findsOneWidget);

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, BrandColors.green);

    final AmbysMathWordmark wordmark =
        tester.widget<AmbysMathWordmark>(find.byType(AmbysMathWordmark));
    expect(wordmark.tone, WordmarkTone.onBrandGreen);
  });

  testWidgets('shows three loading dots and no spinner',
      (WidgetTester tester) async {
    await pump(tester, SplashVariant.cream);

    expect(LoadingDots.colors, hasLength(3));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
