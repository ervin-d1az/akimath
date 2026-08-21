import 'dart:convert';

import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:akimath_app/design/widgets/icon_button_tile.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/features/home/data/prefs_day_log_store.dart';
import 'package:akimath_app/features/home/data/series_cursor_store.dart';
import 'package:akimath_app/features/home/policy/series_families.dart';
import 'package:akimath_app/features/map/data/practised_step_store.dart';
import 'package:akimath_app/features/map/ui/map_route.dart';
import 'package:akimath_app/features/map/ui/node_detail_screen.dart';
import 'package:akimath_app/features/map/ui/skill_map_screen.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(source));
}

/// Two families and six items, which is the smallest pack that makes a map
/// worth drawing: more than one node, and more items in a family than one
/// practice run can hold.
String _pack() {
  String arithmetic(String id, int step) => '''
    {"id": "$id", "ladder_step": $step, "answer": "7",
     "prompt": [{"kind": "text", "value": "3"},
                {"kind": "operator", "glyph": "+"},
                {"kind": "text", "value": "4"},
                {"kind": "operator", "glyph": "="}]}''';
  String series(String id, int step) => '''
    {"id": "$id", "ladder_step": $step, "answer": "8",
     "stimulus": {"kind": "numberSeries",
                  "payload": {"terms": [2, 4, 6, 8], "unknown_index": 3}}}''';

  return '''
{
  "pack_version": 1,
  "pack_id": "test",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "2099-01-01T00:00:00Z",
  "items": [
    ${arithmetic('a1', 1)},
    ${series('s1', 1)},
    ${arithmetic('a2', 2)},
    ${series('s2', 2)},
    ${arithmetic('a3', 3)},
    ${arithmetic('a4', 4)}
  ]
}
''';
}

/// A pack with a topic **longer than one practice run**, so practising it moves
/// the ladder part of the way rather than all of it.
///
/// It is the shipped pack's shape in miniature: `Series` carries steps
/// `1 1 2 2 2 4`, a practice run takes the first five of them, and the step-4
/// item stays out of reach — which is exactly why the device reads 25 % and not
/// 100 % after one run. A six-item topic is the smallest that can show it.
String _ladderPack() {
  String arithmetic(String id, int step) => '''
    {"id": "$id", "ladder_step": $step, "answer": "7",
     "prompt": [{"kind": "text", "value": "3"},
                {"kind": "operator", "glyph": "+"},
                {"kind": "text", "value": "4"},
                {"kind": "operator", "glyph": "="}]}''';
  String series(String id, int step) => '''
    {"id": "$id", "ladder_step": $step, "answer": "8",
     "stimulus": {"kind": "numberSeries",
                  "payload": {"terms": [2, 4, 6, 8], "unknown_index": 3}}}''';

  return '''
{
  "pack_version": 1,
  "pack_id": "test",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "2099-01-01T00:00:00Z",
  "items": [
    ${arithmetic('a1', 1)},
    ${series('s1', 1)},
    ${series('s2', 1)},
    ${series('s3', 2)},
    ${series('s4', 2)},
    ${series('s5', 2)},
    ${series('s6', 4)}
  ]
}
''';
}

/// Answers the item on screen and moves past its verdict.
///
/// The digit is arbitrary: what a practice run records about a topic is the
/// **step it served**, right or wrong, the same way the cursor advances for a
/// series however it went.
Future<void> _answerOne(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate((Widget w) => w is KeypadKeyView && w.data.id == '8'),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byWidgetPredicate(
      (Widget w) => w is KeypadKeyView && w.data.id == 'submit',
    ),
  );
  await tester.pumpAndSettle();

  final Finder onwards = find.text('Siguiente').evaluate().isNotEmpty
      ? find.text('Siguiente')
      : find.text('Intentar otro');
  await tester.tap(onwards);
  await tester.pumpAndSettle();
}

/// The hardware of the phone this app is developed against, measured on the
/// device and copied from `test/design/screen_registry.dart`'s `notchedPhone`.
///
/// It is here rather than imported because the point of these cases is that the
/// **route** must survive it, and the registry walks screens.
const FakeViewPadding _notch = FakeViewPadding(top: 62, bottom: 34);

/// Pumps the route the way `RootScaffold` builds it: **bare**.
///
/// **No `AppShell` around it, and that is the whole point.** The shell puts
/// `const MapRoute()` straight into an `IndexedStack`, so anything the route
/// does not inset for itself is drawn under the Dynamic Island. This helper
/// used to wrap it, which is exactly why every test here passed while the
/// title was illegible on a real phone.
Future<void> _pump(
  WidgetTester tester, {
  required String pack,
  RootVisibility visibility = RootVisibility.showing,
  FakeViewPadding padding = FakeViewPadding.zero,
  Size size = const Size(390, 844),
}) async {
  // **The hardware goes on the view, not into a `MediaQuery` below
  // `MaterialApp`.** A wrapper under `home` sits *below* the app's `Navigator`,
  // so a pushed route is above it and gets a flat rectangle back — which is how
  // the detail screen's case first read as fixed when it was not. The view is
  // where a real phone's insets come from, so both routes see them.
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = padding
    ..viewPadding = padding;
  addTearDown(tester.view.reset);

  await _pumpAgain(tester, pack: pack, visibility: visibility);
}

/// The same tree again, so `didUpdateWidget` runs on the state already there.
///
/// Separate from [_pump] because [_pump] configures the view, and doing that
/// twice would make it unclear which frame a measurement came from.
Future<void> _pumpAgain(
  WidgetTester tester, {
  required String pack,
  required RootVisibility visibility,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AkiMathTheme.build(),
      home: MapRoute(
        reader: PackReader(bundle: _FakeBundle(pack)),
        visibility: visibility,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('reads the pack and maps the families it carries',
      (WidgetTester tester) async {
    await _pump(tester, pack: _pack());

    expect(find.byType(SkillMapScreen), findsOneWidget);
    expect(find.text('Cuentas'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
  });

  testWidgets('a pack it cannot read says so instead of drawing a blank map',
      (WidgetTester tester) async {
    await _pump(tester, pack: '{"items": []}');

    expect(find.byType(SkillMapScreen), findsNothing);
    expect(find.textContaining('no se pudo'), findsOneWidget);
  });

  testWidgets('the map reads the cursor, so a played series shows up on it',
      (WidgetTester tester) async {
    await const SeriesCursorStore().advance(2);
    await _pump(tester, pack: _pack());

    // Items 0 and 1 served: one arithmetic at step 1 of 4, one series at step
    // 1 of 2.
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('opening a topic pushes its detail, and it comes back',
      (WidgetTester tester) async {
    await _pump(tester, pack: _pack());

    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
    expect(find.byType(NodeDetailScreen), findsOneWidget);
    expect(find.text('CUENTAS'), findsOneWidget);

    await tester.tap(find.text('Volver al mapa'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillMapScreen), findsOneWidget);
  });

  testWidgets('a topic that is not the first says what it comes after',
      (WidgetTester tester) async {
    await _pump(tester, pack: _pack());

    await tester.tap(find.text('Series'));
    await tester.pumpAndSettle();

    expect(find.text('Viene de Cuentas.'), findsOneWidget);
    expect(find.text('Es por donde empieza el mapa.'), findsNothing);
  });

  testWidgets('practice plays that topic and nothing else',
      (WidgetTester tester) async {
    await _pump(tester, pack: _pack());

    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practicar 5 retos'));
    await tester.pumpAndSettle();

    final RoundScreen round =
        tester.widget<RoundScreen>(find.byType(RoundScreen));
    expect(round.items, hasLength(4));
    expect(
      round.items.map((Item item) => familyLabel(item.stimulus)).toSet(),
      <String>{'Cuentas'},
    );
  });

  // The defect this group exists for, measured on a device on 2026-08-21: a
  // player opened `2.7` for Series, practised five, came back, and the topic
  // still read 25 %. Of everything a run can leave behind, a practice run left
  // only the day. The trap is that the map's figure came from the **series**
  // cursor, and the one play path that is about a topic is the one path that
  // must not move that cursor — so the button whose whole purpose is to advance
  // a topic was structurally incapable of advancing it.
  group('practising a topic moves that topic', () {
    testWidgets('the number on the topic itself moves, without leaving it',
        (WidgetTester tester) async {
      await _pump(tester, pack: _ladderPack());

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      expect(find.text('0%'), findsOneWidget);

      await tester.tap(find.text('Practicar 5 retos'));
      await tester.pumpAndSettle();
      for (int answered = 0; answered < 5; answered++) {
        await _answerOne(tester);
      }

      // Back on `2.7`, which is where the run started and where a player looks
      // first. It was pushed with a node captured in a `MaterialPageRoute`
      // builder, which Flutter calls once — so it drew the launch-time figure
      // for ever while the map underneath it had moved (PROC-13).
      expect(find.byType(NodeDetailScreen), findsOneWidget);
      // Five served of `1 1 2 2 2 4`: step 2 of the 4 the pack offers.
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
    });

    testWidgets('and so does the number on the map behind it',
        (WidgetTester tester) async {
      await _pump(tester, pack: _ladderPack());

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar 5 retos'));
      await tester.pumpAndSettle();
      for (int answered = 0; answered < 5; answered++) {
        await _answerOne(tester);
      }
      await tester.tap(find.text('Volver al mapa'));
      await tester.pumpAndSettle();

      expect(find.byType(SkillMapScreen), findsOneWidget);
      // Series moved and Cuentas, which nobody practised, did not.
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('it survives the app being closed, because a topic is not one '
        'sitting', (WidgetTester tester) async {
      await _pump(tester, pack: _ladderPack());

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar 5 retos'));
      await tester.pumpAndSettle();
      for (int answered = 0; answered < 5; answered++) {
        await _answerOne(tester);
      }

      // The same preferences a relaunch would read, with no store handed in —
      // which is the only way the device's own default is under test.
      expect(
        await const PrefsPractisedStepStore().read(),
        <String, int>{'numberSeries': 2},
      );
    });

    testWidgets('a run left part-way still counts what it served',
        (WidgetTester tester) async {
      // A player who closes a topic run has still answered what they answered.
      // The cursor takes the opposite view for a *series* — those five items
      // are not "served" in any sense worth remembering, because the home will
      // offer them again — and the difference is real: practice records the
      // step it reached, not a position it will serve from.
      await _pump(tester, pack: _ladderPack());

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar 5 retos'));
      await tester.pumpAndSettle();
      await _answerOne(tester);
      await tester.tap(find.byType(IconButtonTile).first);
      await tester.pumpAndSettle();

      expect(
        await const PrefsPractisedStepStore().read(),
        <String, int>{'numberSeries': 1},
      );
    });

    testWidgets('a topic nobody practised is left where the cursor put it',
        (WidgetTester tester) async {
      // PROC-11's other half: a map that read the practised record *instead* of
      // the cursor would pass every case above and lose every series ever
      // played — which is the live device's 25 %.
      await const SeriesCursorStore().advance(2);
      await _pump(tester, pack: _ladderPack());

      await tester.tap(find.text('Cuentas'));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
    });
  });

  testWidgets('practice leaves the cursor alone, because the cursor decides '
      'which five the home serves next', (WidgetTester tester) async {
    await _pump(tester, pack: _pack());

    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practicar 5 retos'));
    await tester.pumpAndSettle();

    expect(await const SeriesCursorStore().read(), 0);
  });

  testWidgets('practising records the day on the device, with no store handed '
      'in', (WidgetTester tester) async {
    // **The shell hands this route nothing.** `RootScaffold` builds
    // `MapRoute(visibility: …)` and no `dayLog`, `RoundScreen` resolves a null
    // one to no store at all — `store?.record(…)` — and a day practised from
    // Mapa was therefore never written. Every other case here injects a store
    // and so could never see it; this one deliberately does not, which is the
    // only way the default is under test.
    await _pump(tester, pack: _pack());

    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practicar 5 retos'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate((Widget w) => w is KeypadKeyView && w.data.id == '7'),
    );
    await tester.tap(
      find.byWidgetPredicate(
        (Widget w) => w is KeypadKeyView && w.data.id == 'submit',
      ),
    );
    await tester.pumpAndSettle();

    expect((await const PrefsDayLogStore().read()).days, hasLength(1));
  });

  group('the hardware in the way', () {
    // Measured on an iPhone 17 running this build: the title sat at y=6 with
    // 62 px of status bar and Dynamic Island over it, so `MAPA DE TEMAS` read
    // as `MAPA D` with the clock printed across it, and the `0 / 6` chip was
    // under the battery. `HomeRoute` and `ProfileRoute` both return an
    // `AppShell`; this route returned its screen bare.
    testWidgets('the map insets itself, because the shell hands it none',
        (WidgetTester tester) async {
      await _pump(
        tester,
        pack: _pack(),
        padding: _notch,
        size: const Size(402, 874),
      );

      expect(
        tester.getTopLeft(find.text('MAPA DE TEMAS')).dy,
        greaterThanOrEqualTo(_notch.top),
      );
    });

    testWidgets('and so does the topic it opens', (WidgetTester tester) async {
      // A sibling route on the same navigator inherits nothing from the root's
      // inset, so this is a second place to get right rather than the same one.
      // Measured: the back control sat at y=4, entirely under the clock.
      await _pump(
        tester,
        pack: _pack(),
        padding: _notch,
        size: const Size(402, 874),
      );

      await tester.tap(find.text('Cuentas'));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byType(IconButtonTile)).dy,
        greaterThanOrEqualTo(_notch.top),
      );
    });
  });

  // PROC-13. `_contents` was a `late final` future read once in a field
  // initialiser, so the map drew launch-time percentages for ever: play a
  // series on Inicio, come back to Mapa, and nothing had moved. `IndexedStack`
  // keeps every root alive, so there is no second `initState` to hook — the
  // transition to the front is the only signal there is.
  testWidgets('coming to the front re-reads the cursor, and a rebuild behind '
      'does not', (WidgetTester tester) async {
    await _pump(tester, pack: _pack(), visibility: RootVisibility.behind);
    // Two families, nothing served.
    expect(find.text('0%'), findsNWidgets(2));

    // A series is played on Inicio while the map sits behind it.
    await const SeriesCursorStore().advance(2);

    // **A rebuild is not a visit.** The shell rebuilds every root on every tab
    // switch; refreshing on any rebuild would read storage for a screen nobody
    // is looking at, and would hide the case this exists for.
    await _pumpAgain(tester, pack: _pack(), visibility: RootVisibility.behind);
    expect(find.text('25%'), findsNothing);
    expect(find.text('0%'), findsNWidgets(2));

    // Now the player taps `Mapa`.
    await _pumpAgain(tester, pack: _pack(), visibility: RootVisibility.showing);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });
}
