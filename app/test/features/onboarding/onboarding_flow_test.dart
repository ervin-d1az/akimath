import 'dart:convert';

import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/design/widgets/icon_button_tile.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/features/home/data/series_cursor_store.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/onboarding/data/onboarding_store.dart';
import 'package:akimath_app/features/onboarding/ui/calibration_intro_screen.dart';
import 'package:akimath_app/features/onboarding/ui/calibration_item_screen.dart';
import 'package:akimath_app/features/onboarding/ui/calibration_result_screen.dart';
import 'package:akimath_app/features/onboarding/ui/first_item_screen.dart';
import 'package:akimath_app/features/onboarding/ui/first_run_gate.dart';
import 'package:akimath_app/features/onboarding/ui/save_progress_screen.dart';
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
Future<void> _pump(WidgetTester tester, {VoidCallback? onCreateAccount}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final PackReader reader = PackReader(bundle: _FakeBundle());
  await tester.pumpWidget(
    MaterialApp(
      home: FirstRunGate(
        splashFloor: Duration.zero,
        reader: reader,
        onCreateAccount: onCreateAccount,
        home: HomeRoute(reader: reader),
      ),
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

/// Welcome → teaching item → answered → acknowledged, which lands on `0.4`.
Future<void> _walkTeachingItem(WidgetTester tester) async {
  await tester.tap(find.text('Resolver uno'));
  await tester.pumpAndSettle();

  for (final String id in <String>['1', '3', 'submit']) {
    await _press(tester, id);
  }
  await tester.pumpAndSettle();

  await tester.tap(find.text('Siguiente'));
  await tester.pumpAndSettle();
}

/// The whole first run, the long way: the teaching item, the probe answered,
/// the result, and `0.7` dismissed. The fake pack holds one item, so the probe
/// is one item long.
Future<void> _walkFirstRun(WidgetTester tester) async {
  await _walkTeachingItem(tester);

  await tester.tap(find.text('Va, empecemos'));
  await tester.pumpAndSettle();

  for (final String id in <String>['4', '2', 'submit']) {
    await _press(tester, id);
  }
  await tester.pumpAndSettle();

  await tester.tap(find.text('Entrar a mi mapa'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Después'));
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

    testWidgets('submitting continues to the probe, not to the home',
        (WidgetTester tester) async {
      await _pump(tester);
      await _walkTeachingItem(tester);

      expect(find.byType(CalibrationIntroScreen), findsOneWidget);
      expect(find.byType(FirstItemScreen), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('and the whole run ends on the home',
        (WidgetTester tester) async {
      await _pump(tester);
      await _walkFirstRun(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
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

    testWidgets('the probe promises to adapt, and the result claims nothing',
        (WidgetTester tester) async {
      // **This test used to assert the opposite, and D11 is why.** F2 shipped
      // `0.2` and `0.3` alone precisely because `0.4` promises *"unos rápidos
      // para acomodar tu nivel"* and nothing in the build adapts to a level.
      // The four screens were then asked for explicitly, for a demo, with the
      // missing placement named out loud — so D11 is superseded and the honest
      // half of it moves here: the promise may be made on `0.4`, and `0.6` must
      // still claim no level, no rank and no placement, because there is no
      // rating system to produce one.
      const List<String> claims = <String>['nivel', 'rango', 'puesto'];

      await _pump(tester);
      await _walkTeachingItem(tester);
      expect(_copy(tester), contains('acomodar'), reason: '0.4 makes the promise');

      await tester.tap(find.text('Va, empecemos'));
      await tester.pumpAndSettle();
      for (final String id in <String>['4', '2', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();

      expect(find.byType(CalibrationResultScreen), findsOneWidget);
      for (final String word in claims) {
        expect(_copy(tester), isNot(contains(word)), reason: 'on 0.6');
      }
    });

    testWidgets('the words it looks for are words a screen could contain',
        (WidgetTester tester) async {
      // PROC-11's control. A list of words no Spanish copy would ever hold makes
      // the test above pass forever. `_copy` is proven to see real copy, so the
      // negatives above are negatives about the copy and not about the reader.
      await _pump(tester);
      expect(_copy(tester), contains('resolvemos'));
      expect(_copy(tester), contains('aki'));
    });
  });

  group('the probe sits between the teaching item and the home', () {
    testWidgets('skipping it at 0.4 steps over the result entirely',
        (WidgetTester tester) async {
      // Nothing was answered, so there is nothing true to put on `0.6` — the
      // same reading as the profile drawing no `HISTORIAL` section.
      await _pump(tester);
      await _walkTeachingItem(tester);

      await tester.tap(find.text('Saltar por ahora'));
      await tester.pumpAndSettle();

      expect(find.byType(CalibrationResultScreen), findsNothing);
      expect(find.byType(SaveProgressScreen), findsOneWidget);
    });

    testWidgets('leaving it with nothing answered steps over it too',
        (WidgetTester tester) async {
      await _pump(tester);
      await _walkTeachingItem(tester);

      await tester.tap(find.text('Va, empecemos'));
      await tester.pumpAndSettle();
      expect(find.byType(CalibrationItemScreen), findsOneWidget);

      await tester.tap(find.text('Saltar'));
      await tester.pumpAndSettle();

      expect(find.byType(CalibrationResultScreen), findsNothing);
      expect(find.byType(SaveProgressScreen), findsOneWidget);
    });

    testWidgets('answering it reaches the result, and then 0.7',
        (WidgetTester tester) async {
      await _pump(tester);
      await _walkTeachingItem(tester);

      await tester.tap(find.text('Va, empecemos'));
      await tester.pumpAndSettle();
      for (final String id in <String>['4', '2', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();

      expect(find.byType(CalibrationResultScreen), findsOneWidget);

      await tester.tap(find.text('Entrar a mi mapa'));
      await tester.pumpAndSettle();

      expect(find.byType(SaveProgressScreen), findsOneWidget);
    });

    testWidgets('0.7 counts the teaching item and every probe item answered',
        (WidgetTester tester) async {
      await _pump(tester);
      await _walkTeachingItem(tester);

      await tester.tap(find.text('Va, empecemos'));
      await tester.pumpAndSettle();
      for (final String id in <String>['4', '2', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar a mi mapa'));
      await tester.pumpAndSettle();

      final SaveProgressScreen screen =
          tester.widget<SaveProgressScreen>(find.byType(SaveProgressScreen));
      expect(screen.challenges, 2, reason: 'the teaching item plus one probe');
    });

    testWidgets('0.7 reports no day, because the first run records none',
        (WidgetTester tester) async {
      // The `RACHA 1` defect, in its other direction: the teaching item and the
      // probe both pass no `DayLogStore`, so the home behind this screen will
      // read zero days. A tile saying `1 DÍA` would be contradicted one tap
      // later, so there is no tile.
      await _pump(tester);
      await _walkTeachingItem(tester);
      await tester.tap(find.text('Saltar por ahora'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<SaveProgressScreen>(find.byType(SaveProgressScreen)).days,
        0,
      );
      expect(find.text('DÍA'), findsNothing);
      expect(find.text('DÍAS'), findsNothing);
    });

    testWidgets('the home does not re-serve what the probe already asked',
        (WidgetTester tester) async {
      // **The `7 + 6` defect, ten times over.** The probe takes the pack's
      // first ten items; the home previews `pack.items.first` as RETO DEL DÍA
      // and opens its first series at `seriesPlan(pack.items, from: 0)`. Left
      // alone, a player who finished calibration would meet every one of those
      // ten again on the next screen. The probe therefore advances the same
      // cursor a finished series advances.
      await _pump(tester);
      await _walkTeachingItem(tester);

      await tester.tap(find.text('Va, empecemos'));
      await tester.pumpAndSettle();
      for (final String id in <String>['4', '2', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();

      expect(await const SeriesCursorStore().read(), 1);
    });

    testWidgets('and a probe nobody answered advances it by nothing',
        (WidgetTester tester) async {
      // The control. The cursor counts items *served*, and skipping serves
      // none — advancing on the skip would silently cost the player the first
      // ten items of their pack.
      await _pump(tester);
      await _walkTeachingItem(tester);

      await tester.tap(find.text('Saltar por ahora'));
      await tester.pumpAndSettle();

      expect(await const SeriesCursorStore().read(), 0);
    });

    testWidgets('a build with no account flow draws no green button on 0.7',
        (WidgetTester tester) async {
      await _pump(tester);
      await _walkTeachingItem(tester);
      await tester.tap(find.text('Saltar por ahora'));
      await tester.pumpAndSettle();

      expect(find.text('Crear cuenta'), findsNothing);
      expect(find.text('Después'), findsOneWidget);
    });

    testWidgets('and one that has it records the run before handing over',
        (WidgetTester tester) async {
      // **The flag is the gate's, and the gate sets it either way.** A player
      // who leaves for the account flow has seen the whole first run; showing
      // it again after they come back would be the app forgetting.
      int asked = 0;
      await _pump(tester, onCreateAccount: () => asked++);
      await _walkTeachingItem(tester);
      await tester.tap(find.text('Saltar por ahora'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(asked, 1);
      expect(
        await SharedPreferencesAsync().getBool(OnboardingStore.key),
        isTrue,
      );
    });
  });

  group('the first run happens once', () {
    testWidgets('completing it records the flag', (WidgetTester tester) async {
      await _pump(tester);
      await _walkFirstRun(tester);

      expect(await SharedPreferencesAsync().getBool(OnboardingStore.key), isTrue);
    });

    testWidgets('and nothing before 0.7 records it', (WidgetTester tester) async {
      // **The whole run is the first run now.** It used to end at the solved
      // teaching item; four screens sit after it, and the last of them is the
      // only invitation to keep any of it. A flag set at 0.3 would hide them
      // from a player who closed the app on 0.5.
      await _pump(tester);
      await _walkTeachingItem(tester);

      expect(
        await SharedPreferencesAsync().getBool(OnboardingStore.key),
        isNull,
        reason: 'the teaching item completed the first run on its own',
      );
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

    testWidgets('a system back does the same thing as the close control',
        (WidgetTester tester) async {
      // **The `PopScope` claim, asserted.** The teaching item is swapped in
      // rather than pushed, so without it a system back at the root would quit
      // the app while the visible close returned to the welcome — two controls,
      // two meanings. The doc comment said they agree; this is what checks it.
      await _pump(tester);
      await tester.tap(find.text('Resolver uno'));
      await tester.pumpAndSettle();
      expect(find.byType(FirstItemScreen), findsOneWidget);

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      final bool handled = await navigator.maybePop();
      await tester.pumpAndSettle();

      // `maybePop` reports whether the *request* was handled, not whether a
      // route came off the stack: `doNotPop` is handled, and it is what keeps a
      // first-run player inside the app instead of quitting it.
      expect(handled, isTrue, reason: 'the back request went unhandled');
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        await SharedPreferencesAsync().getBool(OnboardingStore.key),
        isNull,
        reason: 'a system back completed the first run',
      );
    });

    testWidgets('there is no skip control to complete the run with',
        (WidgetTester tester) async {
      // The flag-level half of the same defect: a tap on "Saltar este reto"
      // reached `onComplete` and wrote the flag. The control is gone, and this
      // asserts the consequence rather than its absence — a control renamed
      // tomorrow still must not complete a first run.
      await _pump(tester);
      await tester.tap(find.text('Resolver uno'));
      await tester.pumpAndSettle();

      expect(find.text('Saltar este reto'), findsNothing);
      expect(
        await SharedPreferencesAsync().getBool(OnboardingStore.key),
        isNull,
      );
    });

    testWidgets('a system back on the welcome is not intercepted',
        (WidgetTester tester) async {
      // The control. `PopScope` applies only while solving — holding it on the
      // welcome would make a first-run player unable to leave the app at all,
      // which is the opposite failure.
      await _pump(tester);

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      final bool handled = await navigator.maybePop();
      await tester.pumpAndSettle();

      // Unhandled, so it bubbles to the platform and the app closes — which is
      // what back at a root should do. This is also what makes the test above
      // mean something: `true` there is a difference, not a constant.
      expect(handled, isFalse, reason: 'the welcome intercepted a system back');
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });
}
