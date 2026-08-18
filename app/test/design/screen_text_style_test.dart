import 'package:akimath_app/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_registry.dart';

/// No screen paints Flutter's missing-`Material` debug marker.
///
/// A `Text` with no `Material` ancestor inherits `DefaultTextStyle.fallback()`,
/// which paints a **yellow double underline** under every run. It is a debug
/// aid, and on a finished screen it reads as a defect — the round screen shipped
/// with it under every numeral, every keypad key and the header, and nothing in
/// the suite noticed.
///
/// It is invisible to the other gates because it is not a colour literal, not a
/// blur, not an overflow and not a geometry literal. It is a *default* nobody
/// chose, which is exactly the class of thing a registry-driven walk is for.
void main() {
  for (final RegisteredScreen screen in registeredScreens) {
    testWidgets('${screen.label} carries no debug underline',
        (WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: AkiMathTheme.build(), home: screen.build()),
      );

      final Iterable<Text> texts = tester.widgetList<Text>(find.byType(Text));
      expect(
        texts,
        isNotEmpty,
        reason: 'nothing rendered — the check is vacuous',
      );

      for (final Text text in texts) {
        final TextStyle? style = text.style;
        // An explicitly-set underline is a design choice and is left alone.
        // The fallback's signature is the yellow *double* rule.
        final bool looksLikeTheDebugMarker =
            style?.decorationStyle == TextDecorationStyle.double &&
                style?.decorationColor == const Color(0xFFFFFF00);

        expect(
          looksLikeTheDebugMarker,
          isFalse,
          reason: '"${text.data}" in ${screen.label} has no Material ancestor',
        );
      }
    });

    testWidgets('${screen.label} resolves a real default text style',
        (WidgetTester tester) async {
      // The assertion above catches a style set *on* a Text. This catches the
      // inherited case, which is the one that actually bit: the fallback is
      // what a bare Text resolves to when nothing above it supplies a style.
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: AkiMathTheme.build(), home: screen.build()),
      );

      for (final Element element in find.byType(Text).evaluate()) {
        final DefaultTextStyle inherited = DefaultTextStyle.of(element);
        expect(
          inherited.style.decoration,
          anyOf(isNull, TextDecoration.none),
          reason: '${screen.label} inherits the fallback text style, so every '
              'run of text is underlined in yellow',
        );
      }
    });
  }
}
