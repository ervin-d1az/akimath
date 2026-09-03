import 'dart:convert';

import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/api/sync.dart';
import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:akimath_app/features/sync/attempt_sync.dart';
import 'package:akimath_app/features/sync/data/attempt_journal_store.dart';
import 'package:akimath_app/features/sync/data/issued_pack_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The home does not ask for a pack until the account has a player.
///
/// **A session is not a player.** `POST /packs` resolves the player from the
/// session, and that row is written by `POST /players/link` — which the profile
/// fires off the *same* event this route reacts to. Measured against the
/// deployed server on 2026-09-02 (`docs/qa/2026-09-02-first-production-
/// playthrough.md`, finding 1): the two requests started 15 ms apart, issuing
/// answered 404, nothing retried, and the device played the bundled pack for
/// the rest of the process — whose items name no server pack, so a whole
/// five-item series reached `attempts` as nothing at all.
///
/// The cost is permanent rather than a delay: `attempts` takes no UPDATE, so
/// the device's count and the server's diverge for the life of the account.

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(source));
}

const String _onePack = '''
{
  "pack_version": 1,
  "pack_id": "bundled",
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
    }
  ]
}
''';

const LinkedSession _session = LinkedSession(
  email: 'ana@correo.mx',
  accessToken: 'token',
  ageBand: AgeBand.adult,
);

AttemptSync _quietSync() => AttemptSync(
      store: InMemoryAttemptJournalStore(),
      submit: ({
        required String accessToken,
        required List<AttemptSubmission> attempts,
      }) async =>
          const SyncDone(<AttemptVerdict>[]),
    );

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('a session with no player yet asks for no pack',
      (WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final List<String> asked = <String>[];
    // One store and one sync across both pumps, so the second is a rebuild of
    // the same route rather than a fresh device.
    final IssuedPackStore packs = InMemoryIssuedPackStore();
    final AttemptSync sync = _quietSync();

    Widget home(AccountState account) => MaterialApp(
          home: HomeRoute(
            reader: PackReader(bundle: _FakeBundle(_onePack)),
            now: () => DateTime(2026, 8, 16),
            dayLog: InMemoryDayLogStore(),
            sync: sync,
            session: _session,
            account: account,
            issuedPacks: packs,
            issuePack: (String accessToken) async {
              asked.add(accessToken);
              return const IssueNoPlayer();
            },
          ),
        );

    // **The launch where the account is created.** The shell holds a session
    // and the profile has not finished linking, which is the state the log
    // caught: `POST /packs` at 02:52:17.602, `POST /players/link` at .624.
    await tester.pumpWidget(home(AccountState.loading));
    await tester.pumpAndSettle();

    expect(asked, isEmpty,
        reason: 'issuing against an account with no player 404s, and that 404 '
            'is terminal — the device then plays the bundled pack for ever');

    // **The second frame is the test** (PROC-13). The account is a value that
    // flows from `RootScaffold` into this route after it is built, so a route
    // that read it once at construction would never ask at all — the
    // regression this gate has to catch as well as the race.
    await tester.pumpWidget(home(AccountState.linked));
    await tester.pumpAndSettle();

    expect(asked, <String>['token'],
        reason: 'the pack is asked for exactly once, when the player lands');
  });
}
