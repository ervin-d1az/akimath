import 'package:akimath_app/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_registry.dart';

/// Every screen fits the design viewport, at the text size a child's device
/// actually carries.
///
/// The no-blur gate beside this one pumps at 2400×4000 so the character sheet
/// can lay its cards out, which means no test in this repository could go red
/// on a 390×844 overflow. This one closes that hole: it pumps the same
/// registered screens at the viewport the design is drawn against, at
/// `textScaler` 1.0 and 1.3, and fails on any render overflow.
void main() {
  group('the harness', () {
    testWidgets('reports nothing for a screen that fits at 390×844',
        (WidgetTester tester) async {
      expect(
        await pumpAndCollectOverflows(
          tester,
          screen: const _FitsUntilTextGrows(),
          viewport: ScreenViewport.designPhone,
        ),
        isEmpty,
      );
    });

    testWidgets('names the widget that overflowed once the text grows',
        (WidgetTester tester) async {
      final List<String> overflows = await pumpAndCollectOverflows(
        tester,
        screen: const _FitsUntilTextGrows(),
        viewport: ScreenViewport.designPhoneLargeText,
      );

      expect(overflows, hasLength(1));
      expect(
        overflows.single,
        allOf(contains('overflowed'), contains('Column')),
      );
    });
  });

  group('the registry', () {
    test('is not empty', () {
      // An empty registry makes both design gates run zero tests and exit 0,
      // which reads exactly like a clean run.
      expect(registeredScreens, isNotEmpty);
    });

    test('requires every screen at a viewport', () {
      for (final RegisteredScreen screen in registeredScreens) {
        expect(
          screen.requiredViewports,
          isNotEmpty,
          reason: '${screen.label} is excused from every viewport, so it has '
              'no overflow coverage at all.',
        );
      }
    });

    test('holds both splash variants at every viewport, unexcused', () {
      // This change is what fixes the splash, so an exemption the screen once
      // earned is stale the moment it stops overflowing. Scoped to `splash`:
      // §2.6 entitles other screens to an excuse with evidence (design D-6).
      final List<RegisteredScreen> splash =
          screensLabelled('splash', registeredScreens);

      expect(splash, hasLength(2));
      for (final RegisteredScreen variant in splash) {
        expect(
          variant.excused,
          isEmpty,
          reason: '${variant.label} carries an exemption. This change is what '
              'fixes the splash geometry, so the exemption is retired here.',
        );
        expect(variant.requiredViewports, ScreenViewport.values);
      }
    });

    test('lets a viewport be excused only by the message that earned it', () {
      for (final RegisteredScreen screen in registeredScreens) {
        for (final MapEntry<ScreenViewport, String> excuse
            in screen.excused.entries) {
          expect(
            excuse.value,
            contains('overflowed'),
            reason: '${screen.label} is excused from ${excuse.key.label} '
                'without quoting the overflow that earned the excuse. An '
                'exemption is data with evidence, never silence (design D-6).',
          );
        }
      }
    });
  });

  group('the splash clause', () {
    // Proven against a synthetic registry rather than by mutating the real one:
    // an exemption the gate should catch is a value handed to a function here,
    // never an edit to `screen_registry.dart`.
    final List<RegisteredScreen> registryWithExemptions = <RegisteredScreen>[
      RegisteredScreen(
        label: 'splash · cream',
        build: () => const SizedBox.shrink(),
        excused: const <ScreenViewport, String>{
          ScreenViewport.designPhoneLargeText:
              'A RenderFlex overflowed by 12 pixels on the bottom.',
        },
      ),
      RegisteredScreen(
        label: 'character sheet',
        build: () => const SizedBox.shrink(),
        excused: const <ScreenViewport, String>{
          ScreenViewport.designPhone:
              'A RenderFlex overflowed by 900 pixels on the right.',
        },
      ),
    ];

    test('an excused splash would be caught', () {
      expect(
        screensLabelled('splash', registryWithExemptions).single.excused,
        isNotEmpty,
      );
    });

    test('an excused character sheet is none of its business', () {
      // §2.6 entitles the character sheet to its own excuse. A clause that
      // caught it too would be a different rule wearing this one's name.
      expect(
        screensLabelled('splash', registryWithExemptions)
            .map((RegisteredScreen screen) => screen.label),
        <String>['splash · cream'],
      );
    });
  });

  for (final RegisteredScreen screen in registeredScreens) {
    for (final ScreenViewport viewport in screen.requiredViewports) {
      testWidgets('${screen.label} fits ${viewport.label}',
          (WidgetTester tester) async {
        expect(
          await pumpAndCollectOverflows(
            tester,
            screen: screen.build(),
            viewport: viewport,
          ),
          isEmpty,
        );
      });
    }
  }
}

/// The registry entries belonging to one screen family.
///
/// A family is named by the prefix its variants share — `splash` covers both
/// `splash · cream` and `splash · green`. Selecting by prefix is what lets a
/// clause bind the screens one change re-measured without binding every screen
/// in the registry.
List<RegisteredScreen> screensLabelled(
  String prefix,
  List<RegisteredScreen> screens,
) =>
    screens
        .where((RegisteredScreen screen) => screen.label.startsWith(prefix))
        .toList();

/// Pumps [screen] at [viewport] and returns every render overflow reported.
///
/// Overflow is reported through [FlutterError.onError] during paint, so the
/// handler is swapped for the pump and everything that is not an overflow is
/// handed back to the test binding — an unrelated exception still fails the
/// test rather than being swallowed here.
Future<List<String>> pumpAndCollectOverflows(
  WidgetTester tester, {
  required Widget screen,
  required ScreenViewport viewport,
}) async {
  tester.view
    ..physicalSize = viewport.physicalSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final List<String> overflows = <String>[];
  final void Function(FlutterErrorDetails)? reportToBinding =
      FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('overflowed')) {
      overflows.add(details.toString());
      return;
    }
    reportToBinding?.call(details);
  };

  try {
    await tester.pumpWidget(
      MaterialApp(
        theme: AkiMathTheme.build(),
        // The text size is applied below MaterialApp on purpose: WidgetsApp
        // builds its own MediaQuery from the view, so a wrapper above it would
        // be overridden and every screen would silently pass at 1.3.
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(viewport.textScale),
            ),
            child: screen,
          ),
        ),
      ),
    );
  } finally {
    FlutterError.onError = reportToBinding;
  }
  return overflows;
}

/// A screen whose content fits the design viewport and stops fitting once the
/// text size grows: 363 px of fixed chrome and 440 px of type, 803 px in all.
///
/// It stands in for `04 Error`, which measures the same way and belongs to
/// `f2-core-loop`; naming that screen here would be an ordering cycle
/// (design D-1).
class _FitsUntilTextGrows extends StatelessWidget {
  const _FitsUntilTextGrows();

  static const double _chromeHeight = 363;
  static const int _lineCount = 8;
  static const double _lineHeight = 55;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const SizedBox(height: _chromeHeight),
          Text(
            List<String>.filled(_lineCount, 'Aki').join('\n'),
            style: const TextStyle(fontSize: _lineHeight, height: 1),
          ),
        ],
      ),
    );
  }
}
