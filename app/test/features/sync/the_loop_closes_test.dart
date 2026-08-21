import 'dart:convert';

import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/api/sync.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/content/answer_digest.dart';
import 'package:akimath_app/content/model/issued_pack.dart';
import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/model/pack.dart';
import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/round/ui/summary/series_summary_screen.dart';
import 'package:akimath_app/features/sync/attempt_sync.dart';
import 'package:akimath_app/features/sync/data/attempt_journal_store.dart';
import 'package:akimath_app/features/sync/data/issued_pack_store.dart';
import 'package:akimath_app/features/sync/policy/attempt_journal.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Play an item, and watch the answer reach the journal and leave it.
///
/// **This is the gate the whole loop was missing.** `issuePack` and
/// `submitAttempts` had zero callers and the journal had zero writers, so seven
/// endpoints, a provisioned database and digest grading were all unreachable
/// from actually playing — and `HISTORIAL` could never fill however much anyone
/// played. A unit test of each part would have passed the whole time.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.source);
  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(source));
}

/// A pack in the **frozen** format, which is what the server issues: two items,
/// answers stated as digests keyed by the salt.
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
     "stimulus": {"kind": "arithmetic", "payload": {"operator": "+",
       "left": {"num": 5, "den": 1}, "right": {"num": 8, "den": 1}}},
     "answer": {"shape": "integer", "digest": "SEVEN_TEEN"},
     "diagnosis": null}
  ]
}
''';

Future<void> tapKey(WidgetTester tester, String id) async {
  await tester.tap(find.byWidgetPredicate(
    (Widget w) => w is KeypadKeyView && w.data.id == id,
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('an answered issued item reaches the journal and then the server',
      (WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(402, 874)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The pack the device is playing is an issued one: it states a digest for
    // `5 + 8` and the answer is nowhere in it.
    final Pack issued = readIssuedPack(
      jsonDecode(_issuedContent.replaceFirst(
        'SEVEN_TEEN',
        // The real digest of the canonical `13` under this salt.
        _digestOfThirteen(),
      )) as Map<String, dynamic>,
      packId: 'pk_prueba',
      issuedAt: DateTime.utc(2026, 8, 20),
      expiresAt: DateTime.utc(2026, 9, 20),
    );
    expect(issued.items.single.answer, isA<DigestAnswer>());
    expect(issued.items.single.id, 'pk_prueba#0');

    final InMemoryAttemptJournalStore journal = InMemoryAttemptJournalStore();
    final List<List<AttemptSubmission>> sent = <List<AttemptSubmission>>[];
    final AttemptSync sync = AttemptSync(
      store: journal,
      submit: ({
        required String accessToken,
        required List<AttemptSubmission> attempts,
      }) async {
        sent.add(attempts);
        return const SyncDone(<AttemptVerdict>[]);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoundScreen(
          items: issued.items,
          fallbackDiagnosis: issued.fallbackDiagnosis,
          now: () => DateTime.utc(2026, 8, 20, 18),
          dayLog: InMemoryDayLogStore(),
          onAnswered: (Item item, String answer, Duration elapsed) => sync.record(
            itemId: item.id,
            sessionId: 'sesión-de-prueba',
            answer: answer,
            at: DateTime.utc(2026, 8, 20, 18),
            elapsed: elapsed,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Answer 13, which the device grades against the digest with no answer in
    // the file.
    await tapKey(tester, '1');
    await tapKey(tester, '3');
    await tapKey(tester, 'submit');
    await tester.pumpAndSettle();

    expect(find.text('¡Bien hecho!'), findsOneWidget,
        reason: 'the digest verdict never reached the screen');

    final List<JournalledAttempt> held = await journal.read();
    expect(held, hasLength(1), reason: 'the answer never reached the journal');
    expect(held.single.packId, 'pk_prueba');
    expect(held.single.index, 0);
    expect(held.single.answer, '13');

    // And it leaves on a flush.
    await sync.flush('token');

    expect(sent, hasLength(1));
    expect(sent.single.single.packRef?.packId, 'pk_prueba');
    expect(await journal.read(), isEmpty,
        reason: 'a batch that landed should be gone');
  });

  testWidgets('an authored item is played and journalled by nobody',
      (WidgetTester tester) async {
    // The bundled pack has no `(packId, index)`, so there is nothing the server
    // could grade and nothing worth remembering. It still plays.
    tester.view
      ..physicalSize = const Size(402, 874)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final Pack authored = await PackReader(bundle: _Bundle(_authored)).load();
    final InMemoryAttemptJournalStore journal = InMemoryAttemptJournalStore();
    final AttemptSync sync = AttemptSync(store: journal);

    await tester.pumpWidget(
      MaterialApp(
        home: RoundScreen(
          items: authored.items,
          now: () => DateTime.utc(2026, 8, 20, 18),
          dayLog: InMemoryDayLogStore(),
          onAnswered: (Item item, String answer, Duration elapsed) => sync.record(
            itemId: item.id,
            sessionId: 'sesión-de-prueba',
            answer: answer,
            at: DateTime.utc(2026, 8, 20, 18),
            elapsed: elapsed,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapKey(tester, '4');
    await tapKey(tester, '2');
    await tapKey(tester, 'submit');
    await tester.pumpAndSettle();

    expect(find.text('¡Bien hecho!'), findsOneWidget);
    expect(await journal.read(), isEmpty);
  });

  testWidgets('the home sends what is waiting, and only with a session',
      (WidgetTester tester) async {
    final InMemoryAttemptJournalStore journal = InMemoryAttemptJournalStore()
      ..write(<JournalledAttempt>[
        JournalledAttempt(
          packId: 'pk_prueba',
          index: 0,
          sessionId: 'antes',
          answer: '13',
          at: DateTime.utc(2026, 8, 19),
          elapsed: const Duration(seconds: 3),
        ),
      ]);
    int flushes = 0;
    final AttemptSync sync = AttemptSync(
      store: journal,
      submit: ({
        required String accessToken,
        required List<AttemptSubmission> attempts,
      }) async {
        flushes += 1;
        return const SyncDone(<AttemptVerdict>[]);
      },
    );

    tester.view
      ..physicalSize = const Size(402, 874)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // No session: nothing is sent, and the journal keeps what it had.
    await tester.pumpWidget(MaterialApp(
      home: HomeRoute(
        reader: PackReader(bundle: _Bundle(_authored)),
        now: () => DateTime.utc(2026, 8, 20),
        dayLog: InMemoryDayLogStore(),
        sync: sync,
      ),
    ));
    await tester.pumpAndSettle();
    expect(flushes, 0);
    expect(await journal.read(), hasLength(1));

    // With one, it goes.
    await tester.pumpWidget(MaterialApp(
      home: HomeRoute(
        reader: PackReader(bundle: _Bundle(_authored)),
        now: () => DateTime.utc(2026, 8, 20),
        dayLog: InMemoryDayLogStore(),
        sync: sync,
        session: const LinkedSession(
          email: 'ana@correo.mx',
          accessToken: 'token',
          ageBand: AgeBand.adult,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(flushes, 1);
    expect(await journal.read(), isEmpty);
  });

  testWidgets('the home plays the pack it was issued, and the answer leaves',
      (WidgetTester tester) async {
    // **The gate the whole loop was missing.** Every part below had a passing
    // unit test while nothing called any of them: this walks from a home with a
    // session to an answer sitting on the server's doorstep.
    tester.view
      ..physicalSize = const Size(402, 874)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final InMemoryAttemptJournalStore journal = InMemoryAttemptJournalStore();
    final List<List<AttemptSubmission>> sent = <List<AttemptSubmission>>[];
    final AttemptSync sync = AttemptSync(
      store: journal,
      submit: ({
        required String accessToken,
        required List<AttemptSubmission> attempts,
      }) async {
        sent.add(attempts);
        return const SyncDone(<AttemptVerdict>[]);
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: HomeRoute(
        // The bundled pack is what it would play with no session: one item,
        // answer `42`, no address. It must not be what it plays here.
        reader: PackReader(bundle: _Bundle(_authored)),
        now: () => DateTime.utc(2026, 8, 20, 12),
        dayLog: InMemoryDayLogStore(),
        sync: sync,
        session: const LinkedSession(
          email: 'ana@correo.mx',
          accessToken: 'token',
          ageBand: AgeBand.adult,
        ),
        issuePack: (String accessToken) async => IssueDone(
          IssuedPack(
            packId: 'pk_emitido',
            issuedAt: DateTime.utc(2026, 8, 20),
            expiresAt: DateTime.utc(2026, 9, 20),
            pack: jsonDecode(
              _issuedContent.replaceFirst('SEVEN_TEEN', _digestOfThirteen()),
            ) as Map<String, Object?>,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The home is showing the issued pack: its item is `5 + 8`, not the
    // bundled `6 × 7`.
    expect(find.text('5'), findsWidgets);
    expect(find.text('×'), findsNothing, reason: 'still playing the bundled pack');

    await tester.tap(find.text('Empezar la serie'));
    await tester.pumpAndSettle();
    expect(find.byType(RoundScreen), findsOneWidget);

    await tapKey(tester, '1');
    await tapKey(tester, '3');
    await tapKey(tester, 'submit');
    await tester.pumpAndSettle();

    expect(find.text('¡Bien hecho!'), findsOneWidget);

    final List<JournalledAttempt> held = await journal.read();
    expect(held, hasLength(1), reason: 'the answer never reached the journal');
    expect(held.single.packId, 'pk_emitido');
    expect(held.single.index, 0);

    await sync.flush('token');
    expect(sent.single.single.packRef?.packId, 'pk_emitido');
    expect(await journal.read(), isEmpty);
  });

  testWidgets('coming back from a series sends what it journalled',
      (WidgetTester tester) async {
    // **The defect this records.** `_flush` had two callers — the launch, and
    // the session arriving — and returning from a series was neither. So a
    // player answered, came home, and the batch sat on disk until the *next*
    // launch: `HISTORIAL` stayed empty right after playing, which reads as
    // broken. The test above had to call `sync.flush` by hand, which is what
    // that gap looks like from inside a suite.
    tester.view
      ..physicalSize = const Size(402, 874)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final InMemoryAttemptJournalStore journal = InMemoryAttemptJournalStore();
    final List<List<AttemptSubmission>> sent = <List<AttemptSubmission>>[];
    final AttemptSync sync = AttemptSync(
      store: journal,
      submit: ({
        required String accessToken,
        required List<AttemptSubmission> attempts,
      }) async {
        sent.add(attempts);
        return const SyncDone(<AttemptVerdict>[]);
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: HomeRoute(
        reader: PackReader(bundle: _Bundle(_authored)),
        now: () => DateTime.utc(2026, 8, 20, 12),
        dayLog: InMemoryDayLogStore(),
        sync: sync,
        session: const LinkedSession(
          email: 'ana@correo.mx',
          accessToken: 'token',
          ageBand: AgeBand.adult,
        ),
        issuePack: (String accessToken) async => IssueDone(
          IssuedPack(
            packId: 'pk_emitido',
            issuedAt: DateTime.utc(2026, 8, 20),
            expiresAt: DateTime.utc(2026, 9, 20),
            pack: jsonDecode(
              _issuedContent.replaceFirst('SEVEN_TEEN', _digestOfThirteen()),
            ) as Map<String, Object?>,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // **Asserted before anything is played**, or the launch flush would be the
    // thing this test measures.
    expect(sent, isEmpty, reason: 'the launch flush had nothing to send');

    await tester.tap(find.text('Empezar la serie'));
    await tester.pumpAndSettle();
    for (final String key in <String>['1', '3', 'submit']) {
      await tapKey(tester, key);
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.byType(SeriesSummaryScreen), findsOneWidget,
        reason: 'the series never ended');

    await tester.tap(find.text('Volver al inicio'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1),
        reason: 'nothing was sent when the series came back');
    expect(sent.single.single.packRef?.packId, 'pk_emitido');
    expect(await journal.read(), isEmpty,
        reason: 'a batch that landed should be gone');
  });

  group('a pack survives a relaunch', () {
    IssuedPack issued(String id) => IssuedPack(
          packId: id,
          issuedAt: DateTime.utc(2026, 8, 20),
          expiresAt: DateTime.utc(2026, 9, 20),
          pack: jsonDecode(
            _issuedContent.replaceFirst('SEVEN_TEEN', _digestOfThirteen()),
          ) as Map<String, Object?>,
        );

    Future<void> launch(
      WidgetTester tester, {
      required IssuedPackStore packs,
      required List<String> issues,
      required List<String> fetches,
      FetchPackResult Function(String packId)? answerFetch,
    }) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: HomeRoute(
          reader: PackReader(bundle: _Bundle(_authored)),
          now: () => DateTime.utc(2026, 8, 20, 12),
          dayLog: InMemoryDayLogStore(),
          sync: AttemptSync(store: InMemoryAttemptJournalStore()),
          issuedPacks: packs,
          session: const LinkedSession(
            email: 'ana@correo.mx',
            accessToken: 'token',
            ageBand: AgeBand.adult,
          ),
          issuePack: (String accessToken) async {
            issues.add(accessToken);
            return IssueDone(issued('pk_nuevo${issues.length}'));
          },
          fetchPack: ({
            required String accessToken,
            required String packId,
          }) async {
            fetches.add(packId);
            return answerFetch?.call(packId) ?? FetchPackDone(issued(packId));
          },
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the first launch issues one and writes the id down',
        (WidgetTester tester) async {
      final InMemoryIssuedPackStore packs = InMemoryIssuedPackStore();
      final List<String> issues = <String>[];
      final List<String> fetches = <String>[];

      await launch(tester, packs: packs, issues: issues, fetches: fetches);

      expect(issues, hasLength(1));
      expect(fetches, isEmpty);
      expect(await packs.read(), 'pk_nuevo1');
    });

    testWidgets('the next one fetches it and issues nothing',
        (WidgetTester tester) async {
      // **The whole point of the change.** Before this the device minted a row
      // per launch per player; the server rebuilds byte for byte, so a fetch is
      // the same pack.
      final InMemoryIssuedPackStore packs = InMemoryIssuedPackStore('pk_guardado');
      final List<String> issues = <String>[];
      final List<String> fetches = <String>[];

      await launch(tester, packs: packs, issues: issues, fetches: fetches);

      expect(fetches, <String>['pk_guardado']);
      expect(issues, isEmpty, reason: 'it minted a second pack');
      expect(await packs.read(), 'pk_guardado');
    });

    testWidgets('a pack the server no longer has is replaced, once',
        (WidgetTester tester) async {
      // A 404 is the one answer meaning *there is no such pack for you* —
      // gone, lapsed, or somebody else's, which the server cannot tell apart on
      // purpose.
      final InMemoryIssuedPackStore packs = InMemoryIssuedPackStore('pk_viejo');
      final List<String> issues = <String>[];
      final List<String> fetches = <String>[];

      await launch(
        tester,
        packs: packs,
        issues: issues,
        fetches: fetches,
        answerFetch: (String _) => const FetchPackGone(),
      );

      expect(fetches, <String>['pk_viejo']);
      expect(issues, hasLength(1));
      expect(await packs.read(), 'pk_nuevo1');
    });

    testWidgets('a network blip mints nothing', (WidgetTester tester) async {
      // Refused, broken or unreachable: the id is still good and the bundled
      // pack still plays. Issuing here would mint a row for a blip.
      final InMemoryIssuedPackStore packs = InMemoryIssuedPackStore('pk_guardado');
      final List<String> issues = <String>[];
      final List<String> fetches = <String>[];

      await launch(
        tester,
        packs: packs,
        issues: issues,
        fetches: fetches,
        answerFetch: (String _) => const FetchPackUnreachable('sin red'),
      );

      expect(issues, isEmpty);
      expect(await packs.read(), 'pk_guardado');
    });
  });
}

const String _authored = '''
{
  "pack_version": 1,
  "pack_id": "prueba",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "2099-01-01T00:00:00Z",
  "misconceptions": {
    "no_specific_diagnosis": {
      "steps": ["Lee otra vez el reto, sin prisa."],
      "explain": "Repasa el reto con calma."
    }
  },
  "items": [
    {"id": "a1", "ladder_step": 2, "answer": "42",
     "prompt": [{"kind": "text", "value": "6"}, {"kind": "operator", "glyph": "×"},
                {"kind": "text", "value": "7"}, {"kind": "operator", "glyph": "="}]}
  ]
}
''';

/// The digest of the canonical `13` under the salt the fixture declares.
///
/// Computed rather than pasted: a hand-written digest in a fixture is the
/// mistake `ARCHITECTURE.md` §3 records, and one that would make this test pass
/// while the real thing was wrong.
String _digestOfThirteen() => answerDigest(
      saltHex: 'a1b2c3d4e5f60718293a4b5c6d7e8f90',
      canonicalAnswer: '13',
    );
