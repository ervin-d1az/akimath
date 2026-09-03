import 'dart:convert';

import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:akimath_app/design/widgets/icon_button_tile.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/api/sync.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/data/prefs_day_log_store.dart';
import 'package:akimath_app/features/home/data/series_cursor_store.dart';
import 'package:akimath_app/features/home/policy/day_log.dart';
import 'package:akimath_app/features/home/policy/series_families.dart';
import 'package:akimath_app/features/map/data/practised_step_store.dart';
import 'package:akimath_app/features/map/ui/map_route.dart';
import 'package:akimath_app/features/map/ui/node_detail_screen.dart';
import 'package:akimath_app/features/map/ui/skill_map_screen.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
import 'package:akimath_app/features/stats/data/answer_record_store.dart';
import 'package:akimath_app/features/stats/policy/local_stats.dart';
import 'package:akimath_app/features/sync/attempt_sync.dart';
import 'package:akimath_app/features/sync/data/attempt_journal_store.dart';
import 'package:akimath_app/features/sync/data/issued_pack_store.dart';
import 'package:akimath_app/features/sync/policy/attempt_journal.dart';
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

/// The same pack, with the ids an **issued** pack carries.
///
/// `readIssuedItemId` reads an id as `packId#index` and returns null for
/// anything else, so an authored item is dropped by `AttemptSync.record` on
/// purpose — nothing on the server addresses it. Both shapes are fixtures here
/// because the difference is the whole reason a practice run does or does not
/// reach the server, and a test written only against one of them would report
/// a loop that closes when it does not.
String _issuedShapedPack() => _ladderPack().replaceAllMapped(
      RegExp(r'"id": "(a|s)(\d)"'),
      (Match m) => '"id": "pk-1#${m.group(2)}"',
    );

/// A pack in the **frozen** format, which is what the server issues: two number
/// series, answers stated as digests keyed by the salt. `readIssuedPack` mints
/// each item's id as `packId#index`, which is the address the journal needs.
const String _issuedContent = '''
{
  "pack_format_version": 1,
  "pack_salt": "a1b2c3d4e5f60718293a4b5c6d7e8f90",
  "skill_nodes": [],
  "skill_fallbacks": [
    {"skill_id": 1, "diagnosis": {"misconception": "no_specific_diagnosis",
      "steps": ["Lee otra vez el reto, sin prisa."],
      "explain": "Repasa el reto con calma."}}
  ],
  "puzzles": [],
  "items": [
    {"skill_id": 1, "ladder_step": 1, "keypad": "item",
     "stimulus": {"kind": "numberSeries",
       "payload": {"terms": [2, 4, 6, 8], "unknown_index": 3}},
     "answer": {"shape": "integer",
       "digest": "0f0e0d0c0b0a09080706050403020100"},
     "diagnosis": null},
    {"skill_id": 1, "ladder_step": 2, "keypad": "item",
     "stimulus": {"kind": "numberSeries",
       "payload": {"terms": [3, 6, 9, 12], "unknown_index": 3}},
     "answer": {"shape": "integer",
       "digest": "100f0e0d0c0b0a090807060504030201"},
     "diagnosis": null}
  ]
}
''';

const LinkedSession _session = LinkedSession(
  email: 'geineryodan@gmail.com',
  accessToken: 'token',
  ageBand: AgeBand.adult,
);

/// A `GET /packs/{packId}` that always answers with [content].
Future<FetchPackResult> Function({
  required String accessToken,
  required String packId,
}) _fetches(String content) => ({
      required String accessToken,
      required String packId,
    }) async => FetchPackDone(
          IssuedPack(
            packId: packId,
            issuedAt: DateTime.utc(2026, 8, 1),
            expiresAt: DateTime.utc(2099),
            pack: json.decode(content),
          ),
        );

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
  DayLogStore? dayLog,
  AnswerRecordStore? answerRecord,
  AttemptSync? sync,
  LinkedSession? session,
  IssuedPackStore? issuedPacks,
  Future<FetchPackResult> Function({
    required String accessToken,
    required String packId,
  })? fetchPack,
  DateTime Function()? now,
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

  await _pumpAgain(
    tester,
    pack: pack,
    visibility: visibility,
    dayLog: dayLog,
    answerRecord: answerRecord,
    sync: sync,
    session: session,
    issuedPacks: issuedPacks,
    fetchPack: fetchPack,
    now: now,
  );
}

/// The same tree again, so `didUpdateWidget` runs on the state already there.
///
/// Separate from [_pump] because [_pump] configures the view, and doing that
/// twice would make it unclear which frame a measurement came from.
Future<void> _pumpAgain(
  WidgetTester tester, {
  required String pack,
  required RootVisibility visibility,
  DayLogStore? dayLog,
  AnswerRecordStore? answerRecord,
  AttemptSync? sync,
  LinkedSession? session,
  IssuedPackStore? issuedPacks,
  Future<FetchPackResult> Function({
    required String accessToken,
    required String packId,
  })? fetchPack,
  DateTime Function()? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AkiMathTheme.build(),
      home: MapRoute(
        reader: PackReader(bundle: _FakeBundle(pack)),
        visibility: visibility,
        dayLog: dayLog,
        answerRecord: answerRecord,
        sync: sync,
        session: session,
        issuedPacks: issuedPacks,
        fetchPack: fetchPack,
        now: now ?? DateTime.now,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A [DayLog] holding [days], built the only way one can be — by recording.
DayLog _seeded(List<DateTime> days) {
  DayLog log = DayLog.empty;
  for (final DateTime day in days) {
    log = log.recording(day);
  }
  return log;
}

/// The [count] days ending yesterday, so a round today makes a run of
/// `count + 1`.
List<DateTime> _daysBeforeToday(int count) {
  final DateTime today = DateTime.now();
  return <DateTime>[
    for (int back = count; back >= 1; back--)
      DateTime(today.year, today.month, today.day).subtract(
        Duration(days: back),
      ),
  ];
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

  testWidgets('a lapsed pack draws no map, so no topic offers a practice run',
      (WidgetTester tester) async {
    // Arrange: the bundled pack's own window, closed. No server and no session
    // are involved — this is the file on the device having run out.
    await _pump(tester, pack: _pack().replaceAll('2099-01-01', '2020-01-01'));

    // The absence alone would also pass for a pack that could not be read,
    // which is a different defect with a different message — so the sentence
    // is what makes the absence mean *lapsed*. Inicio has refused this pack
    // since it landed; Mapa drew every topic with a live `Practicar 5 retos`.
    expect(find.byType(SkillMapScreen), findsNothing);
    expect(find.textContaining('vencieron'), findsOneWidget);
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

  // Three losses measured beside the one above, on the same device and the same
  // night. A practice run reported nothing to the device's own figures, nothing
  // to the journal, and told the round the player had practised on no day at
  // all. The home path wires all three; this one wired none.
  group('a practice run counts everywhere a series counts', () {
    testWidgets('every answer reaches the record the profile reads',
        (WidgetTester tester) async {
      final InMemoryAnswerRecordStore record = InMemoryAnswerRecordStore();
      await _pump(tester, pack: _ladderPack(), answerRecord: record);

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar 5 retos'));
      await tester.pumpAndSettle();
      await _answerOne(tester);
      await _answerOne(tester);

      // `8` is the answer every series item in the fixture carries, so both are
      // right — which is the half that could be faked by recording a constant.
      // The verdict has to travel, so the third answer is deliberately wrong.
      await tester.tap(
        find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == '3',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == 'submit',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        (await record.read()).map((AnsweredItem a) => a.verdict),
        <Verdict>[Verdict.correct, Verdict.correct, Verdict.wrong],
      );
    });

    testWidgets('an answer the server can address reaches the journal',
        (WidgetTester tester) async {
      final InMemoryAttemptJournalStore journal =
          InMemoryAttemptJournalStore();
      await _pump(
        tester,
        pack: _issuedShapedPack(),
        sync: AttemptSync(store: journal),
      );

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar 5 retos'));
      await tester.pumpAndSettle();
      await _answerOne(tester);
      await _answerOne(tester);

      final List<JournalledAttempt> held = await journal.read();
      expect(held, hasLength(2));
      // One sitting, one session id: `GET /me/history` groups by it, and a
      // history of one-item sessions is a history nobody can read.
      expect(
        held.map((JournalledAttempt a) => a.sessionId).toSet(),
        hasLength(1),
      );
      // The address the server grades by, not the position in the run.
      expect(held.map((JournalledAttempt a) => a.index), <int>[1, 2]);
    });

    testWidgets('and it is stamped with the route\'s clock, not the ambient one',
        (WidgetTester tester) async {
      // **The one field in the sync path no test could pin.** This route read
      // `DateTime.now()` straight into the attempt while `HomeRoute` threaded
      // `widget.now` through six call sites, so the moment that travels to the
      // server was decided by whichever wall clock the process happened to
      // have. Asserting the *value* rather than that a timestamp exists is what
      // makes the injection real: a bare `DateTime.now()` cannot produce this.
      final DateTime moment = DateTime.utc(2026, 8, 20, 9, 30);
      final InMemoryAttemptJournalStore journal =
          InMemoryAttemptJournalStore();
      await _pump(
        tester,
        pack: _issuedShapedPack(),
        sync: AttemptSync(store: journal),
        now: () => moment,
      );

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar 5 retos'));
      await tester.pumpAndSettle();
      await _answerOne(tester);

      expect((await journal.read()).single.at, moment);
    });

    testWidgets('an authored item reaches it as nothing at all, and says so '
        'here rather than at a 404', (WidgetTester tester) async {
      // The contrast that keeps the case above honest. `_ladderPack` carries the
      // bundled pack's ids, which name no `(packId, index)` — so this is what
      // the app really does today whenever it is playing the pack it ships.
      final InMemoryAttemptJournalStore journal =
          InMemoryAttemptJournalStore();
      await _pump(
        tester,
        pack: _ladderPack(),
        sync: AttemptSync(store: journal),
      );

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar 5 retos'));
      await tester.pumpAndSettle();
      await _answerOne(tester);

      expect(await journal.read(), isEmpty);
    });

    testWidgets('the verdict reports the run the player is really on',
        (WidgetTester tester) async {
      // `attemptDays: const <DateTime>[]` told the round the player had
      // practised on no day ever, while a store underneath it recorded today —
      // so `03 Acierto` printed `RACHA 1` to somebody on a run of four. That is
      // the two-screens-one-morning contradiction `StreakPolicy` was fixed for,
      // and it was reintroduced one screen over.
      await _pump(
        tester,
        pack: _ladderPack(),
        dayLog: InMemoryDayLogStore(_seeded(_daysBeforeToday(3))),
      );

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar 5 retos'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == '8',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == 'submit',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RACHA'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('and a second run the same day does not add a day',
        (WidgetTester tester) async {
      // The realistic sequence, and the one handing `_log.days` to the round
      // creates: practise, `_read` puts **today** into the log, practise again,
      // and the round appends today a second time. `streakLength` collapses to
      // a set of whole days, so the figure holds — asserted here rather than
      // assumed, because the store it reads from does dedup and the list handed
      // past it does not.
      await _pump(
        tester,
        pack: _ladderPack(),
        dayLog: InMemoryDayLogStore(
          _seeded(<DateTime>[..._daysBeforeToday(2), DateTime.now()]),
        ),
      );

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar 5 retos'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == '8',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == 'submit',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsNothing);
    });
  });

  // The half that makes the wiring above worth having. `AttemptSync.record`
  // drops an item with no `(packId, index)`, and the map read the bundled pack
  // — whose items are authored — so a practice run could journal correctly and
  // still reach the server as nothing. The home plays what the server issued;
  // this root played the asset for ever, which also meant its percentages
  // described a pack the player was not being served.
  group('the map plays the pack the server can grade', () {
    testWidgets('it fetches the pack the home was issued, and grades against '
        'that one', (WidgetTester tester) async {
      final InMemoryAttemptJournalStore journal =
          InMemoryAttemptJournalStore();
      await _pump(
        tester,
        pack: _ladderPack(),
        session: _session,
        issuedPacks: InMemoryIssuedPackStore('pk_mapa'),
        fetchPack: _fetches(_issuedContent),
        sync: AttemptSync(store: journal),
      );

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar 5 retos'));
      await tester.pumpAndSettle();
      await _answerOne(tester);

      final List<JournalledAttempt> held = await journal.read();
      expect(held, hasLength(1));
      expect(held.single.packId, 'pk_mapa');
    });

    testWidgets('the bundled pack keeps playing when there is nothing to '
        'fetch', (WidgetTester tester) async {
      // Unlinked play is entirely offline (ADR 0002), and a device with no
      // issued pack is the ordinary state rather than a failure. It must not
      // become a blank map.
      await _pump(tester, pack: _ladderPack(), session: _session);

      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Cuentas'), findsOneWidget);
    });

    testWidgets('a fetch that fails leaves the bundled pack playing',
        (WidgetTester tester) async {
      // A blip on a request the player never made is not worth a screen, and
      // the app they already had works. The map never *issues* — that is the
      // home's, which is also what writes the id this reads.
      await _pump(
        tester,
        pack: _ladderPack(),
        session: _session,
        issuedPacks: InMemoryIssuedPackStore('pk_mapa'),
        fetchPack: ({
          required String accessToken,
          required String packId,
        }) async => const FetchPackUnreachable('no network'),
      );

      expect(find.byType(SkillMapScreen), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
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

  testWidgets('a topic already open stops offering practice when the pack '
      'lapses under it', (WidgetTester tester) async {
    // **The hole the root's own refusal leaves.** `2.7` is pushed above the map
    // rather than drawn inside it, so it keeps the figures it was opened with
    // while a re-read is in flight — which is right for a number and wrong for
    // a door. Practising from here plays the pack the root has just stopped
    // playing, which is the finding one screen further in.
    DateTime moment = DateTime.utc(2026, 8, 20);
    await _pump(
      tester,
      pack: _pack(),
      visibility: RootVisibility.behind,
      now: () => moment,
    );
    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
    expect(find.text('Practicar 5 retos'), findsOneWidget);

    // The window closes while the player is standing on the topic, and they
    // switch tabs and come back — the one signal this root gets to re-read.
    moment = DateTime.utc(2100);
    await _pumpAgain(
      tester,
      pack: _pack(),
      visibility: RootVisibility.showing,
      now: () => moment,
    );

    // Absent rather than dead: a control that cannot act reads as broken, and
    // `onPractise` is nullable for exactly this (DR-P2). The way back is the
    // control the screen already draws.
    expect(find.text('Practicar 5 retos'), findsNothing);
    expect(find.text('Volver al mapa'), findsOneWidget);
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
