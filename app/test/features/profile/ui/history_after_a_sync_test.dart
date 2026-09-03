import 'dart:async';
import 'dart:math';

import 'package:akimath_app/features/sync/attempt_sync.dart';
import 'package:akimath_app/features/sync/data/attempt_journal_store.dart';
import 'package:akimath_app/api/sync.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:akimath_app/api/history.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/features/account/data/player_id_store.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
import 'package:akimath_app/features/stats/data/answer_record_store.dart';
import 'package:akimath_app/features/sync/data/recorded_batch_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether `HISTORIAL` catches up with a batch that landed after it was asked.
///
/// **Measured against the deployed server on 2026-09-02.** On the launch that
/// flushed the attempt journal the two happened 116 ms apart, in the wrong
/// order:
///
/// ```
/// 03:51:04.581  GET  /me/history  200   (empty)
/// 03:51:04.697  POST /attempts    200   (five rows land)
/// ```
///
/// Perfil drew **no `HISTORIAL` section at all** while the server held a
/// complete session, and only the next relaunch showed it.
///
/// **Both halves are pinned, and the second is the one that makes this bite.**
/// A test that only proved "it asked again" would pass for a route that asks on
/// every visit — which is a request per tab switch for ever and is precisely
/// what this must not be (PROC-11). So every case counts the requests.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.session,
    required this.fetch,
    required this.recorded,
  });

  final LinkedSession session;
  final Future<HistoryResult> Function(String accessToken) fetch;
  final RecordedBatchStore recorded;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  RootVisibility _visibility = RootVisibility.behind;

  /// What the shell does when a player taps Perfil.
  void comeToTheFront() => setState(() => _visibility = RootVisibility.showing);

  /// And leaves it again, so a second visit is a second transition.
  void goBehind() => setState(() => _visibility = RootVisibility.behind);

  @override
  Widget build(BuildContext context) => ProfileRoute(
        visibility: _visibility,
        session: widget.session,
        fetchHistory: widget.fetch,
        recordedBatches: widget.recorded,
        dayLog: InMemoryDayLogStore(),
        answerRecord: InMemoryAnswerRecordStore(),
        playerIds: _NoPlayerId(),
        link: _neverLinks,
        whoAmI: _neverAsks,
        now: () => DateTime.utc(2026, 9, 2),
        authBaseUrl: '',
      );
}

Future<LinkResult> _neverLinks({
  required String accessToken,
  required String playerId,
  required AgeBand ageBand,
}) async =>
    const LinkUnreachable('this test is not about linking');

Future<MeResult> _neverAsks(String accessToken) async =>
    const MeUnreachable('this test is not about the account');

class _NoPlayerId implements PlayerIdStore {
  @override
  Future<String> readOrMint() async => '00000000-0000-4000-8000-000000000000';
}

void main() {
  const LinkedSession session = LinkedSession(
    email: 'a@b.mx',
    accessToken: 'token',
    ageBand: AgeBand.adult,
  );

  final History oneSession = History(<HistoryEntry>[
    HistoryEntry(
      kind: HistoryKind.series,
      title: 'Restas',
      at: DateTime.utc(2026, 9, 2, 3, 51),
      score: '5/5',
      ratingDelta: null,
    ),
  ]);

  /// A server that is empty until a batch is recorded, which is the sequence
  /// the log above shows.
  ({
    List<String> asked,
    Future<HistoryResult> Function(String) fetch,
    void Function() flush,
  }) serverThatFillsUp() {
    final List<String> asked = <String>[];
    bool filled = false;
    return (
      asked: asked,
      fetch: (String token) async {
        asked.add(token);
        return HistoryFound(filled ? oneSession : const History(<HistoryEntry>[]));
      },
      flush: () => filled = true,
    );
  }

  Future<void> pumpAt(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  testWidgets('a batch recorded after the ask is read on the next visit',
      (WidgetTester tester) async {
    final ({
      List<String> asked,
      Future<HistoryResult> Function(String) fetch,
      void Function() flush,
    }) server = serverThatFillsUp();
    final InMemoryRecordedBatchStore recorded = InMemoryRecordedBatchStore();

    await pumpAt(
      tester,
      _Harness(session: session, fetch: server.fetch, recorded: recorded),
    );
    expect(server.asked, hasLength(1), reason: 'the launch asked once');
    expect(find.text('HISTORIAL'), findsNothing,
        reason: 'the server was empty when it was asked');

    // What the home does 116 ms later: the journal flushes and the server
    // records it.
    server.flush();
    await recorded.countOne();

    tester.state<_HarnessState>(find.byType(_Harness)).comeToTheFront();
    await tester.pumpAndSettle();

    expect(server.asked, hasLength(2), reason: 'a batch landed since the ask');
    expect(find.text('HISTORIAL'), findsOneWidget);
    expect(find.text('Restas'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
  });

  testWidgets('a visit with nothing recorded since asks nothing',
      (WidgetTester tester) async {
    // The negative half. Without it this file passes for a route that fetches
    // on every tab switch, which is a request per switch for the life of the
    // app and buys an answer it already has.
    final ({
      List<String> asked,
      Future<HistoryResult> Function(String) fetch,
      void Function() flush,
    }) server = serverThatFillsUp();

    await pumpAt(
      tester,
      _Harness(
        session: session,
        fetch: server.fetch,
        recorded: InMemoryRecordedBatchStore(),
      ),
    );
    expect(server.asked, hasLength(1));

    final _HarnessState shell = tester.state<_HarnessState>(find.byType(_Harness));
    shell.comeToTheFront();
    await tester.pumpAndSettle();
    shell.goBehind();
    await tester.pumpAndSettle();
    shell.comeToTheFront();
    await tester.pumpAndSettle();

    expect(server.asked, hasLength(1),
        reason: 'two visits, and nothing new to learn on either');
  });

  testWidgets('a refused session is not asked again however many visits',
      (WidgetTester tester) async {
    // The constraint this must not break: asking twice with a dead token gets
    // the same refusal, so Perfil offers no retry. It holds by construction —
    // `SyncRejected` is not a recording, so the tally never moves — and this is
    // the case that says so from the reading side.
    final List<String> asked = <String>[];
    final InMemoryRecordedBatchStore recorded = InMemoryRecordedBatchStore();

    await pumpAt(
      tester,
      _Harness(
        session: session,
        fetch: (String token) async {
          asked.add(token);
          return const HistoryRejected(tag: 'unauthorized', message: 'expired');
        },
        recorded: recorded,
      ),
    );
    expect(asked, hasLength(1));
    expect(find.text('Tu sesión caducó. Vuelve a entrar.'), findsOneWidget);

    final _HarnessState shell = tester.state<_HarnessState>(find.byType(_Harness));
    shell.goBehind();
    await tester.pumpAndSettle();
    shell.comeToTheFront();
    await tester.pumpAndSettle();

    expect(asked, hasLength(1), reason: 'a dead token answers the same twice');
  });

  testWidgets('the rows already drawn stay drawn while the next ask is in '
      'flight', (WidgetTester tester) async {
    // A refresh is not a first read. Blanking to a skeleton and back would take
    // a section a player is looking at away from them for a frame — two
    // transitions where the answer needs none.
    final List<Completer<HistoryResult>> pending =
        <Completer<HistoryResult>>[];
    final InMemoryRecordedBatchStore recorded = InMemoryRecordedBatchStore();

    await pumpAt(
      tester,
      _Harness(
        session: session,
        fetch: (String token) {
          final Completer<HistoryResult> next = Completer<HistoryResult>();
          pending.add(next);
          return next.future;
        },
        recorded: recorded,
      ),
    );
    pending.single.complete(HistoryFound(oneSession));
    await tester.pumpAndSettle();
    expect(find.text('Restas'), findsOneWidget);

    await recorded.countOne();
    tester.state<_HarnessState>(find.byType(_Harness)).comeToTheFront();
    await tester.pumpAndSettle();

    expect(pending, hasLength(2), reason: 'a second ask is in flight');
    expect(find.text('Restas'), findsOneWidget,
        reason: 'the rows a player is looking at do not blank out');

    pending.last.complete(HistoryFound(oneSession));
    await tester.pumpAndSettle();
    expect(find.text('Restas'), findsOneWidget);
  });

  testWidgets('the two defaults meet on the device, with nothing wiring them',
      (WidgetTester tester) async {
    // **The claim the whole fix rests on**, and it is a claim about two default
    // arguments in two files rather than about anything a reader can see in one
    // of them. `AttemptSync` is built by Inicio and by Mapa and this root is
    // built by neither, so if their two `PrefsRecordedBatchStore` defaults ever
    // named different keys the app would go on drawing an empty `HISTORIAL`
    // with every suite above still green. This is the case that would notice.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = null);

    bool filled = false;
    final List<String> asked = <String>[];
    final AttemptSync sync = AttemptSync(
      store: InMemoryAttemptJournalStore(),
      submit: ({
        required String accessToken,
        required List<AttemptSubmission> attempts,
      }) async =>
          const SyncDone(<AttemptVerdict>[]),
      random: Random(7),
    );
    await sync.record(
      itemId: 'pk_1#3',
      sessionId: 'sesión',
      answer: '13',
      at: DateTime.utc(2026, 9, 2, 3, 51),
      elapsed: const Duration(seconds: 4),
    );

    await pumpAt(
      tester,
      _Harness(
        session: session,
        fetch: (String token) async {
          asked.add(token);
          return HistoryFound(
              filled ? oneSession : const History(<HistoryEntry>[]));
        },
        // The app's own default on both sides, named nowhere but here.
        recorded: const PrefsRecordedBatchStore(),
      ),
    );
    expect(asked, hasLength(1));

    // What the home does on the launch that flushes: a batch lands, and this
    // root is told nothing.
    filled = true;
    await sync.flush('token');

    tester.state<_HarnessState>(find.byType(_Harness)).comeToTheFront();
    await tester.pumpAndSettle();

    expect(asked, hasLength(2), reason: 'the tally the home wrote is the tally '
        'this root reads');
    expect(find.text('Restas'), findsOneWidget);
  });

}
