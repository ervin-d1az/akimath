import 'dart:async';
import 'dart:convert';

import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/api/sync.dart';
import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/states/ui/offline_screen.dart';
import 'package:akimath_app/features/sync/attempt_sync.dart';
import 'package:akimath_app/features/sync/data/attempt_journal_store.dart';
import 'package:akimath_app/features/sync/data/issued_pack_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Whether `4.9 Sin conexión` is ever *reached*, and whether it lies when it is.
///
/// **The screen shipped with no caller.** It renders, it is in the design
/// registry, and nothing routed to it — the `pack.puzzles.first` shape. It was
/// deliberately not hung off the profile, because its headline is a count of
/// the pack in play and only this route holds one.
///
/// The trigger has to be *evidence*, not a guess: the launch asked the server
/// for a pack and nothing answered. That is the same reading
/// `accountStateFor` gives `MeUnreachable`, and it is the only network fact
/// this route ever learns. Every other answer — a refusal, a 5xx, a 404 — is
/// the server talking, so it is not this screen.

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(source));
}

/// Two items and no board, so the counts on the screen are unmistakable: a
/// screen that invented them, or read the wrong pack, would not print 2 and 0.
const String _twoItemPack = '''
{
  "pack_version": 1,
  "pack_id": "test",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "2099-01-01T00:00:00Z",
  "misconceptions": {
    "no_specific_diagnosis": {
      "steps": ["Lee otra vez el reto, sin prisa."],
      "explain": "Repasa el reto con calma."
    }
  },
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
    },
    {
      "id": "b2",
      "ladder_step": 2,
      "answer": "17",
      "prompt": [
        {"kind": "text", "value": "8"},
        {"kind": "operator", "glyph": "+"},
        {"kind": "text", "value": "9"},
        {"kind": "operator", "glyph": "="}
      ]
    }
  ]
}
''';

/// A pack whose window has closed. The home refuses it with a message, so a
/// bag counted over it would be a bag nobody can open.
const String _expiredPack = '''
{
  "pack_version": 1,
  "pack_id": "test",
  "issued_at": "2020-01-01T00:00:00Z",
  "expires_at": "2020-02-01T00:00:00Z",
  "misconceptions": {
    "no_specific_diagnosis": {
      "steps": ["Lee otra vez el reto, sin prisa."],
      "explain": "Repasa el reto con calma."
    }
  },
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

const LinkedSession _session = LinkedSession(
  email: 'ana@correo.mx',
  accessToken: 'token',
  ageBand: AgeBand.adult,
);

/// A sync that never reaches a socket, so only the pack request is in play.
AttemptSync _quietSync() => AttemptSync(
      store: InMemoryAttemptJournalStore(),
      submit: ({
        required String accessToken,
        required List<AttemptSubmission> attempts,
      }) async =>
          const SyncDone(<AttemptVerdict>[]),
    );

Widget _home({
  required Future<IssueResult> Function(String accessToken) issuePack,
  LinkedSession? session = _session,
  String source = _twoItemPack,
  IssuedPackStore? issuedPacks,
  Future<FetchPackResult> Function({
    required String accessToken,
    required String packId,
  })? fetchPack,
}) {
  return MaterialApp(
    home: HomeRoute(
      reader: PackReader(bundle: _FakeBundle(source)),
      now: () => DateTime(2026, 8, 16),
      dayLog: InMemoryDayLogStore(),
      sync: _quietSync(),
      session: session,
      issuePack: issuePack,
      fetchPack: fetchPack,
      issuedPacks: issuedPacks ?? InMemoryIssuedPackStore(),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(home);
  await tester.pumpAndSettle();
}

Future<IssueResult> _unreachable(String accessToken) async =>
    const IssueUnreachable('no route to host');

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('4.9 is reached when nothing answered, and only then', () {
    testWidgets('a launch whose pack request never landed says so',
        (WidgetTester tester) async {
      await _pump(tester, _home(issuePack: _unreachable));

      expect(find.byType(OfflineScreen), findsOneWidget);
      expect(find.byType(OfflineNotice), findsOneWidget);
    });

    testWidgets('the bag it counts is the pack that is actually in play',
        (WidgetTester tester) async {
      // The count is the whole reason this screen is pushed from here rather
      // than from the profile, so a wrong one is the defect worth catching.
      await _pump(tester, _home(issuePack: _unreachable));

      expect(find.text('2'), findsOneWidget);
      expect(find.text('RETOS'), findsOneWidget);
      expect(find.textContaining('2 RETOS'), findsOneWidget);
      // A pile with nothing in it is left out rather than printed as a zero —
      // `bagTally`'s own rule, and this pack carries no board.
      expect(find.text('0'), findsNothing);
      expect(find.text('PUZZLES'), findsNothing);
    });

    testWidgets('a refused session is not offline', (WidgetTester tester) async {
      // A 401 is the server talking. `AccountState` calls that `rejected`, and
      // a yellow "no signal" over it would be the wrong thing to say.
      await _pump(
        tester,
        _home(
          issuePack: (String _) async =>
              const IssueRejected(tag: 'unauthorized', message: 'no'),
        ),
      );

      expect(find.byType(OfflineScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a server that answered badly is not offline',
        (WidgetTester tester) async {
      await _pump(
        tester,
        _home(
          issuePack: (String _) async =>
              const IssueFailed(status: 500, reason: 'boom'),
        ),
      );

      expect(find.byType(OfflineScreen), findsNothing);
    });

    testWidgets('an account with no player yet is not offline',
        (WidgetTester tester) async {
      await _pump(
        tester,
        _home(issuePack: (String _) async => const IssueNoPlayer()),
      );

      expect(find.byType(OfflineScreen), findsNothing);
    });

    testWidgets('a fetch that never landed says so too',
        (WidgetTester tester) async {
      // The other half of the request: a device that already holds a pack id
      // fetches rather than issues, and the same silence means the same thing.
      await _pump(
        tester,
        _home(
          issuedPacks: InMemoryIssuedPackStore('pack-42'),
          fetchPack: ({
            required String accessToken,
            required String packId,
          }) async =>
              const FetchPackUnreachable('no route to host'),
          issuePack: (String _) async =>
              fail('a fetch that went nowhere must not mint a pack'),
        ),
      );

      expect(find.byType(OfflineScreen), findsOneWidget);
    });

    testWidgets('an unlinked device is never told it is offline',
        (WidgetTester tester) async {
      // **No session, no request, no evidence.** Unlinked play is entirely
      // offline by design (ADR 0002), so "sin conexión" would be a permanent
      // banner over the ordinary state of most of the app's players.
      await _pump(
        tester,
        _home(
          session: null,
          issuePack: (String _) async => fail('nothing to ask on'),
        ),
      );

      expect(find.byType(OfflineScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('it does not land on top of something else', () {
    testWidgets('a pack that cannot be played is not counted as a bag',
        (WidgetTester tester) async {
      // The home already refuses an expired pack with a message. A screen over
      // it announcing challenges in the bag, whose one action opens nothing,
      // is two contradictory things on one launch.
      await _pump(
        tester,
        _home(issuePack: _unreachable, source: _expiredPack),
      );

      expect(find.byType(OfflineScreen), findsNothing);
      expect(find.textContaining('ya vencieron'), findsOneWidget);
    });

    testWidgets('a request that answers mid-series waits, and misses its turn',
        (WidgetTester tester) async {
      // **The case a dead network actually produces.** Nothing answering
      // usually means a socket timing out, which is minutes — long after the
      // player tapped `Empezar la serie`. A full-screen notice over an item is
      // the one interruption declared rule 1 says a session never has.
      final Completer<IssueResult> answer = Completer<IssueResult>();

      await _pump(tester, _home(issuePack: (String _) => answer.future));
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.text('Empezar la serie'));
      await tester.pumpAndSettle();
      expect(find.byType(RoundScreen), findsOneWidget);

      answer.complete(const IssueUnreachable('timed out'));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineScreen), findsNothing);
      expect(find.byType(RoundScreen), findsOneWidget);
    });

    testWidgets('a session that arrives later does not interrupt',
        (WidgetTester tester) async {
      // **The trigger is the launch, not the session.** A session appears when
      // a player links on the profile tab — where `IndexedStack` keeps this
      // route alive and invisible — and the link itself just proved the
      // network works, so a blip on the next request is not a state.
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_home(
        session: null,
        issuePack: (String _) async => fail('nothing to ask on'),
      ));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_home(issuePack: _unreachable));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineScreen), findsNothing);
    });
  });

  group('its one action plays the pack it counted', () {
    testWidgets('solving offline opens a round and leaves the notice behind',
        (WidgetTester tester) async {
      await _pump(tester, _home(issuePack: _unreachable));

      await tester.tap(find.text('Resolver sin conexión'));
      await tester.pumpAndSettle();

      expect(find.byType(RoundScreen), findsOneWidget);
      expect(find.byType(OfflineScreen), findsNothing);
    });

    testWidgets('coming back from that round does not show it again',
        (WidgetTester tester) async {
      // Once a launch. `_refreshLog` runs on every return from a series, and
      // a notice re-pushed there would meet the player after every round.
      await _pump(tester, _home(issuePack: _unreachable));

      await tester.tap(find.text('Resolver sin conexión'));
      await tester.pumpAndSettle();

      for (final String id in <String>['4', '2', 'submit']) {
        await tester.tap(find.byWidgetPredicate(
          (Widget w) => w is KeypadKeyView && w.data.id == id,
        ));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(RoundScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(OfflineScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
