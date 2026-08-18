import 'dart:convert';
import 'dart:typed_data';

import 'package:akimath_app/design/brand/aki.dart';
import 'package:akimath_app/design/math/math_view.dart';
import 'package:akimath_app/design/widgets/icon_button_tile.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/design/widgets/stat_tile.dart';
import 'package:akimath_app/design/widgets/speech_bubble.dart';
import 'package:akimath_app/design/widgets/verdict_ring.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/onboarding/ui/first_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Every asset key the widget under test asked the engine for.
///
/// `PackReader` reads through `rootBundle`, which goes over the `flutter/assets`
/// channel — so recording the channel is how "no pack is read" becomes a fact
/// about behaviour rather than a fact about the constructor's parameter list.
late List<String> assetsRequested;

void _recordAssetLoads() {
  assetsRequested = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    if (message != null) {
      assetsRequested.add(utf8.decode(message.buffer.asUint8List()));
    }
    // Not found. A screen that reads a pack fails visibly rather than quietly
    // succeeding against a fixture this test never wrote.
    return null;
  });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onFinished,
  VoidCallback? onBack,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: FirstItemScreen(
        onFinished: onFinished ?? () {},
        onBack: onBack ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, String id) async {
  await tester.tap(
    find.byWidgetPredicate((Widget w) => w is KeypadKeyView && w.data.id == id),
  );
  await tester.pump();
}

/// The glyphs the compositor drew for the prompt, and only those.
///
/// **There are two `MathView`s on this screen.** The keypad's fraction key is
/// one too — `a` over a bar over `b`, at 15 px — so matching every `MathView` on
/// the screen collects the key's letters along with the expression. The prompt is
/// the one at display size.
Iterable<String> _promptGlyphs(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(
      of: find.byWidgetPredicate(
        (Widget w) => w is MathView && w.size == MathView.defaultNumeral,
      ),
      matching: find.byType(Text),
    ))
    .map((Text t) => t.data ?? '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    _recordAssetLoads();
  });

  group('the teaching item measures nothing', () {
    testWidgets('the prompt is the fixed teaching item',
        (WidgetTester tester) async {
      await _pump(tester);

      expect(_promptGlyphs(tester), <String>['5', '+', '8', '=']);
      // The answer is typed, never shown.
      expect(_promptGlyphs(tester), isNot(contains('13')));
    });

    testWidgets('13 is what it grades as right', (WidgetTester tester) async {
      // The other half of "it is the teaching item": the expected answer. A
      // screen showing `5 + 8` and grading against something else would satisfy
      // the assertion above.
      await _pump(tester);
      for (final String id in <String>['1', '3', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();

      expect(
        tester.widget<VerdictRing>(find.byType(VerdictRing)).verdict,
        Verdict.correct,
      );
    });

    testWidgets('no pack is read', (WidgetTester tester) async {
      await _pump(tester);
      for (final String id in <String>['1', '3', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();

      expect(
        assetsRequested.where((String key) => key.contains('packs')),
        isEmpty,
        reason: 'the teaching screen reached for a pack: $assetsRequested',
      );
    });

    testWidgets('the recorder would have seen a pack read',
        (WidgetTester tester) async {
      // **The control for the test above.** "No pack was requested" is also true
      // of a harness that observes nothing, which is no test at all (PROC-11).
      // `HomeRoute` does read the pack, through the same `rootBundle`, so this
      // proves the instrument works before the other test trusts its silence.
      await tester.pumpWidget(const MaterialApp(home: HomeRoute()));
      await tester.pumpAndSettle();

      expect(
        assetsRequested.where((String key) => key.contains('packs')),
        isNotEmpty,
      );
    });

    testWidgets('answering it records no day, so no streak starts here',
        (WidgetTester tester) async {
      // D4. The screen passes no `DayLogStore`, and this is the observable
      // consequence: submitting writes nothing at all. Wire a store into it and
      // the day-log key appears.
      await _pump(tester);
      for (final String id in <String>['1', '3', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();

      // `isEmpty` subsumes "no day-log key"; asserting both said it twice.
      expect(
        await SharedPreferencesAsync().getKeys(),
        isEmpty,
        reason: 'the tutorial wrote to storage',
      );
    });

    testWidgets('its verdict shows no streak either',
        (WidgetTester tester) async {
      // **The number, not just the storage.** `RoundScreen` used to append
      // `finishedAt` to the streak unconditionally, so the tutorial's verdict
      // read `RACHA 1` while the home behind it read `0` — the same two-screens
      // one-morning contradiction `StreakPolicy` was fixed for, in the other
      // direction, and on a first-run player's very first result.
      await _pump(tester);
      for (final String id in <String>['1', '3', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();

      expect(find.text('RACHA'), findsOneWidget);
      final Finder streak = find.ancestor(
        of: find.text('RACHA'),
        matching: find.byType(StatTile),
      );
      final Iterable<String> figures = tester
          .widgetList<Text>(
            find.descendant(of: streak, matching: find.byType(Text)),
          )
          .map((Text t) => t.data ?? '')
          .where((String text) => text != 'RACHA');

      expect(
        figures,
        <String>['0'],
        reason: 'the tutorial claimed a streak it recorded nowhere',
      );
    });
  });

  group('Aki does not appear while the learner is solving', () {
    testWidgets('she is not in the tree', (WidgetTester tester) async {
      await _pump(tester);

      expect(find.byType(Aki), findsNothing);
      expect(find.byType(SpeechBubble), findsNothing);
    });

    testWidgets('she returns on the verdict, which is not a solve',
        (WidgetTester tester) async {
      // The rule is about solving, not about the screen — asserting only her
      // absence would be satisfied by removing her from the app.
      await _pump(tester);
      for (final String id in <String>['1', '3', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();

      expect(find.byType(Aki), findsOneWidget);
    });
  });

  group('finishing and leaving are different things', () {
    testWidgets('acknowledging the verdict finishes the run',
        (WidgetTester tester) async {
      int finished = 0;
      int back = 0;
      await _pump(tester, onFinished: () => finished++, onBack: () => back++);

      for (final String id in <String>['1', '3', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(finished, 1);
      expect(back, 0, reason: 'finishing was reported as leaving');
    });

    testWidgets('the close control leaves without finishing',
        (WidgetTester tester) async {
      // A mistaken tap on close must not set the flag: skipping the only screen
      // that teaches the answer format should cost seconds, not the tutorial.
      int finished = 0;
      int back = 0;
      await _pump(tester, onFinished: () => finished++, onBack: () => back++);

      await tester.tap(find.byType(IconButtonTile).first);
      await tester.pumpAndSettle();

      expect(back, 1);
      expect(finished, 0, reason: 'leaving completed the first run');
    });

    testWidgets('a single item never offers a second one',
        (WidgetTester tester) async {
      // Without `onFinished`, `RoundScreen` cycles — which is right for a
      // practice series and wrong here. This is that difference, asserted.
      int finished = 0;
      await _pump(tester, onFinished: () => finished++);

      for (final String id in <String>['1', '3', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(finished, 1);
      // It reports and stops. The screen stays on the verdict it just showed —
      // no second item is composed, no keypad comes back, and the flow is what
      // moves on from here. Cycling would put `Reto 1` back on screen with an
      // empty draft, which is the defect this asserts against.
      expect(find.byType(VerdictRing), findsOneWidget);
      expect(find.byType(Keypad), findsNothing);
    });

    testWidgets('asking for another go is not finishing either',
        (WidgetTester tester) async {
      // **The worst of the three exits.** A wrong verdict's continue button is
      // labelled *"Intentar otro"* — a request for another go — and it routed to
      // the same `_next` as *"Siguiente"*. So the child who answered *wrong*, the
      // one who most needs the screen that teaches the answer format, is the one
      // who permanently lost it by tapping the button the app offered them. There
      // is no reset path: no settings screen, and nothing else reads the flag.
      int finished = 0;
      await _pump(tester, onFinished: () => finished++);

      for (final String id in <String>['9', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();
      expect(find.text('Intentar otro'), findsOneWidget);

      await tester.tap(find.text('Intentar otro'));
      await tester.pumpAndSettle();

      expect(finished, 0, reason: 'a wrong answer completed the first run');
      // Another go means the item back, with an empty slot.
      expect(find.byType(Keypad), findsOneWidget);
      expect(_promptGlyphs(tester), <String>['5', '+', '8', '=']);
    });

    testWidgets('and then solving it does finish', (WidgetTester tester) async {
      // The control: retrying must not have made the run unfinishable.
      int finished = 0;
      await _pump(tester, onFinished: () => finished++);

      for (final String id in <String>['9', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Intentar otro'));
      await tester.pumpAndSettle();

      for (final String id in <String>['1', '3', 'submit']) {
        await _press(tester, id);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(finished, 1);
    });

    testWidgets('there is nothing to skip, so no skip control is offered',
        (WidgetTester tester) async {
      // **This was a live defect.** "Saltar este reto" routes to `_next`, which
      // on the last item calls `onFinished` — so one tap completed the first run
      // permanently, with no item ever solved, one row below a close control
      // that deliberately does not. The two exits meant opposite things and
      // looked the same.
      int finished = 0;
      await _pump(tester, onFinished: () => finished++);

      expect(find.text('Saltar este reto'), findsNothing);
      expect(finished, 0);
    });
  });

  group('the house rules hold here too', () {
    testWidgets('no visible timer and no system keyboard',
        (WidgetTester tester) async {
      await _pump(tester);

      expect(find.byType(EditableText), findsNothing);
      for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(matches(RegExp(r'\d+:\d\d'))));
      }
    });

    testWidgets('the keypad is the app\'s own', (WidgetTester tester) async {
      await _pump(tester);
      expect(find.byType(Keypad), findsOneWidget);
    });
  });
}
