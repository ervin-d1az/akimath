import 'package:akimath_app/api/auth_result.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/features/account/data/player_id_store.dart';
import 'package:akimath_app/features/account/data/session_store.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/home/ui/home_route.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:akimath_app/features/shell/ui/root_scaffold.dart';
import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// How *there is a player* travels from the root that learns it to the root
/// that needs it.
///
/// **The chain is three links and the middle one is a constructor argument**,
/// which is exactly the shape PROC-13 says a data path dies in silently. The
/// profile links, the shell holds what came back, the home reads it before it
/// asks for a pack — and every one of those has to work or the home waits for
/// ever on a link that already landed.
///
/// It exists because the home used to wait on the *session* instead, which the
/// profile links off too: measured against the deployed server on 2026-09-02,
/// `POST /packs` and `POST /players/link` started 15 ms apart, issuing answered
/// 404, and nothing retried.

const String _devicePlayer = '018f4e3c-0000-7000-8000-0000000000b1';

const LinkedSession _session = LinkedSession(
  email: 'ana@correo.mx',
  accessToken: 'token',
  ageBand: AgeBand.adult,
);

const StoredSession _stored = StoredSession(
  email: 'ana@correo.mx',
  ageBand: AgeBand.adult,
  provider: AuthSession('better-auth.session_token=abc123'),
);

Me _me() => Me(
      playerId: _devicePlayer,
      ageBand: AgeBand.adult,
      createdAt: DateTime.utc(2026, 8, 20),
    );

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('the profile says so every time it learns it',
      (WidgetTester tester) async {
    final List<AccountState> reported = <AccountState>[];

    Widget route(LinkedSession? session) => MaterialApp(
          home: ProfileRoute(
            session: session,
            playerIds: InMemoryPlayerIdStore(_devicePlayer),
            authBaseUrl: 'https://auth.example/neondb/auth',
            now: () => DateTime.utc(2026, 8, 20),
            onAccountChanged: reported.add,
            fetchHistory: (String accessToken) async => const HistoryNoPlayer(),
            link: ({
              required String accessToken,
              required String playerId,
              required AgeBand ageBand,
            }) async =>
                LinkDone(_me()),
          ),
        );

    // Two pumps, because signing in is a changed field on a root the
    // `IndexedStack` keeps alive and never a construction (PROC-13).
    await tester.pumpWidget(route(null));
    await tester.pumpAndSettle();
    expect(reported, isEmpty, reason: 'nothing to report with no session');

    await tester.pumpWidget(route(_session));
    await tester.pumpAndSettle();

    // **Both, in order.** `loading` is what the home must not mistake for a
    // player, and `linked` is the moment it may ask.
    expect(reported, <AccountState>[AccountState.loading, AccountState.linked]);
  });

  testWidgets('and the shell carries it to the home',
      (WidgetTester tester) async {
    // **The link answers over `flutter_test`'s mocked transport, which is a
    // 400** — so the account lands on `serverError`. That is the point: the
    // assertion is that a value the *profile produced* reaches the home, and
    // any value but the `AccountState.none` default proves the chain. Asserting
    // `linked` here would need the shell to inject a link closure it has no
    // other reason to expose.
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: RootScaffold(
        sessions: InMemorySessionStore(_stored),
        deriveToken: (AuthSession session) async =>
            const AuthOk<String>('nuevo.token'),
      ),
    ));

    AccountState accountAtTheHome() => tester
        .widget<HomeRoute>(find.byType(HomeRoute, skipOffstage: false))
        .account;

    expect(accountAtTheHome(), AccountState.none,
        reason: 'nothing has been read from storage yet');

    await tester.pumpAndSettle();

    expect(accountAtTheHome(), isNot(AccountState.none),
        reason: 'what the profile learned never reached the home, so the home '
            'would wait for a player for ever');
    expect(accountAtTheHome(), AccountState.serverError);
  });
}
