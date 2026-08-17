import 'dart:convert';

import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/design/widgets/icon_button_tile.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/onboarding/data/onboarding_store.dart';
import 'package:akimath_app/features/onboarding/ui/first_item_screen.dart';
import 'package:akimath_app/features/onboarding/ui/first_run_gate.dart';
import 'package:akimath_app/features/onboarding/ui/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(_pack));
}

const String _pack = '''
{
  "pack_version": 1,
  "pack_id": "test",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "2099-01-01T00:00:00Z",
  "items": [
    {
      "id": "a1",
      "ladder_step": 2,
      "answer": "42",
      "prompt": [
        {"kind": "text", "value": "6"},
        {"kind": "operator", "glyph": "×"},
        {"kind": "text", "value": "7"},
        {"kind": "operator", "glyph": "="}
      ]
    }
  ]
}
''';

/// The gate over a home that needs no real asset bundle.
///
/// The real `FirstRunGate` builds `const HomeRoute()`, which reads the shipped
/// pack. Handing in the same route over a fake bundle is what keeps these tests
/// about the *first run* rather than about `assets/packs/starter.json`.
Future<void> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: FirstRunGate(home: HomeRoute(reader: PackReader(bundle: _FakeBundle()))),
    ),
  );
  await tester.pumpAndSettle();
}

/// A relaunch, not a rebuild.
///
/// **Pumping the same tree twice is not a second launch.** The widgets are
/// structurally identical, so Flutter *updates* the existing elements:
/// `initState` never runs again, the flag is never re-read, and the flow keeps
/// whichever screen it was on. Both launch tests below passed and failed for
/// reasons that had nothing to do with the flag until this unmounted first.
Future<void> _relaunch(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await _pump(tester);
}

Future<void> _press(WidgetTester tester, String id) async {
  await tester.tap(
    find.byWidgetPredicate((Widget w) => w is KeypadKeyView && w.data.id == id),
  );
  await tester.pump();
}

/// Walks the whole first run: welcome → teaching item → answered → acknowledged.
Future<void> _walkFirstRun(WidgetTester tester) async {
  await tester.tap(find.text('Resolver uno'));
  await tester.pumpAndSettle();

  for (final String id in <String>['1', '3', 'submit']) {
    await _press(tester, id);
  }
  await tester.pumpAndSettle();

  await tester.tap(find.text('Siguiente'));
  await tester.pumpAndSettle();
}

/// Every string the current screen renders, lowercased.
String _copy(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => (t.data ?? '').toLowerCase())
    .join(' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('the first run reaches a playable item without an account', () {
    testWidgets('a fresh install opens on the welcome',
        (WidgetTester tester) async {
      await _pump(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('its primary action shows the teaching item',
        (WidgetTester tester) async {
      await _pump(tester);
      await tester.tap(find.text('Resolver uno'));
      await tester.pumpAndSettle();

      expect(find.byType(FirstItemScreen), findsOneWidget);
      expect(find.byType(Keypad), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('submitting continues to the home', (WidgetTester tester) async {
      await _pump(tester);
      await _walkFirstRun(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(FirstItemScreen), findsNothing);
    });

    testWidgets('no field asks for an email or a password',
        (WidgetTester tester) async {
      await _pump(tester);
      expect(find.byType(EditableText), findsNothing);
      expect(_copy(tester), isNot(contains('correo')));
      expect(_copy(tester), isNot(contains('contraseña')));

      await tester.tap(find.text('Resolver uno'));
      await tester.pumpAndSettle();

      // The app's own keypad is the only input on the path. `EditableText` is
      // what a text field renders, so its absence is the assertion.
      expect(find.byType(EditableText), findsNothing);
      expect(_copy(tester), isNot(contains('correo')));
    });

    testWidgets('no calibration screen is reachable',
        (WidgetTester tester) async {
      // D11: F2 ships `0.2` and `0.3`. `0.4` would promise a level this build
      // cannot adapt to, so nothing on the path may name one.
      await _pump(tester);
      for (final String word in <String>['nivel', 'calibra', 'acomodar']) {
        expect(_copy(tester), isNot(contains(word)));
      }

      await _walkFirstRun(tester);

      expect(find.byType(HomeScreen), findsOneWidget,
          reason: 'something stood between the item and the home');
    });
  });

  group('the first run happens once', () {
    testWidgets('completing it records the flag', (WidgetTester tester) async {
      await _pump(tester);
      await _walkFirstRun(tester);

      expect(await SharedPreferencesAsync().getBool(OnboardingStore.key), isTrue);
    });

    testWidgets('the second launch goes straight to the home',
        (WidgetTester tester) async {
      // Two mounts over one storage is what two launches look like from here.
      await _pump(tester);
      await _walkFirstRun(tester);

      await _relaunch(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('a launch that has not completed it shows the welcome again',
        (WidgetTester tester) async {
      // The control for the test above: relaunching *without* finishing must
      // still open on the welcome, or "straight to the home" would be true of a
      // gate that never shows the onboarding at all.
      await _pump(tester);
      await tester.tap(find.text('Resolver uno'));
      await tester.pumpAndSettle();

      await _relaunch(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('storage that cannot be read shows the welcome',
        (WidgetTester tester) async {
      // A `bool` key holding a `String` throws a `TypeError` on read. The gate
      // must open on the welcome rather than fail the launch.
      await SharedPreferencesAsync()
          .setString(OnboardingStore.key, 'not a flag');

      await _pump(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('leaving the teaching item returns to the welcome', () {
    testWidgets('the close control does not complete the run',
        (WidgetTester tester) async {
      await _pump(tester);
      await tester.tap(find.text('Resolver uno'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(IconButtonTile).first);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        await SharedPreferencesAsync().getBool(OnboardingStore.key),
        isNull,
        reason: 'leaving the item completed the first run',
      );
    });
  });
}
