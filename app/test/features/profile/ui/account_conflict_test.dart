import 'package:akimath_app/api/api_client.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/account/data/player_id_store.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/preferences/policy/erasure.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The device holds one account's player and signs in as another.
///
/// **Measured on a real device, and the screen lied.** One simulator, two
/// accounts: the id in `shared_preferences` was minted for the first, the
/// player signed in as the second, `POST /players/link` answered 409, and the
/// app drew *"Esta cuenta ya se está usando en otro teléfono."* There was no
/// other phone, and the banner offered nothing — `erasureOffered` is false for
/// a conflict, a retry is gated to offline and server errors, and no sign-out
/// was surfaced. The player was signed in, told something untrue, and had no
/// door.
///
/// Two genuinely different conflicts land on that one 409 and the app collapsed
/// them. These tests hold the two apart and hold the door open.
const String _devicePlayer = '018f4e3c-0000-7000-8000-0000000000b1';
const String _someoneElse = '018f4e3c-0000-7000-8000-0000000000c2';

const LinkedSession _accountB = LinkedSession(
  email: 'theblossom@ejemplo.com',
  accessToken: 'account.b.token',
  ageBand: AgeBand.adult,
);

Me _profile(String playerId) => Me(
  playerId: playerId,
  ageBand: AgeBand.adult,
  createdAt: DateTime.utc(2026, 8, 20),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The route reads four device stores on every visit. An in-memory backend
  // keeps them from reaching a plugin that is not there — the route survives
  // either way, and the warnings it prints would otherwise bury a real one.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  late List<String> probed;
  late List<LinkedSession?> sessions;

  /// Pumps the route with no session, then with one, and settles.
  ///
  /// **Two pumps, deliberately (PROC-13).** The session travels from
  /// `RootScaffold` into a root the `IndexedStack` keeps alive, so signing in
  /// is a *changed field on an existing widget*, never a construction. A test
  /// that pumped once would check the half that never breaks — which is exactly
  /// how sign-in died on this route before.
  Future<void> signIn(
    WidgetTester tester, {
    required LinkResult Function() link,
    required MeResult Function() probe,
  }) async {
    probed = <String>[];
    sessions = <LinkedSession?>[];

    Widget route(LinkedSession? session) => MaterialApp(
      home: ProfileRoute(
        session: session,
        playerIds: InMemoryPlayerIdStore(_devicePlayer),
        authBaseUrl: 'https://auth.example/neondb/auth',
        now: () => DateTime.utc(2026, 8, 20),
        onSessionChanged: sessions.add,
        // **Injected so this route opens no socket.** A conflicting account
        // has no player, so `HistoryState.empty` is also the truthful answer —
        // and it offers no retry of its own, which keeps the one this test
        // looks for unambiguous.
        fetchHistory: (String accessToken) async => const HistoryNoPlayer(),
        link: ({
          required String accessToken,
          required String playerId,
          required AgeBand ageBand,
        }) async => link(),
        whoAmI: (String accessToken) async {
          probed.add(accessToken);
          return probe();
        },
      ),
    );

    await tester.pumpWidget(route(null));
    await tester.pumpAndSettle();
    await tester.pumpWidget(route(_accountB));
    await tester.pumpAndSettle();
  }

  testWidgets('this phone´s progress belonging to another account says so',
      (WidgetTester tester) async {
    // The account is new and holds no player, so the 409 can only be the second
    // refusal: the id on disk still belongs to the account it was linked to.
    await signIn(
      tester,
      link: () => const LinkConflict('that player already belongs to another account'),
      probe: () => const MeNoPlayer(),
    );

    expect(probed, hasLength(1), reason: 'the conflict is refined by asking once');
    expect(find.textContaining('es de otra cuenta'), findsOneWidget);
    // **The sentence that was on screen tonight, and it was false.**
    expect(find.textContaining('otro teléfono'), findsNothing);
  });

  testWidgets('and it offers a door the player can actually walk through',
      (WidgetTester tester) async {
    // Signing back in as the account the id belongs to makes `linkOutcome`
    // answer `existing`, which is a 200 — so this door genuinely resolves the
    // conflict rather than only dismissing the message.
    await signIn(
      tester,
      link: () => const LinkConflict('that player already belongs to another account'),
      probe: () => const MeNoPlayer(),
    );

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    // The shell owns the session and persists it, so this is the only thing
    // that actually forgets the account — and it is what makes the door work
    // across a relaunch rather than only until the next launch.
    expect(sessions, <LinkedSession?>[null]);
  });

  testWidgets('an account whose player is elsewhere still names the phone',
      (WidgetTester tester) async {
    // The other refusal, and here *"otro teléfono"* is the true sentence: the
    // account already has a player and it is not this device's.
    await signIn(
      tester,
      link: () => const LinkConflict('this account already has a player'),
      probe: () => MeFound(_profile(_someoneElse)),
    );

    expect(find.textContaining('otro teléfono'), findsOneWidget);
    // Nothing to press: moving a player between accounts is a decision nobody
    // has made, and signing out would not recover the progress either.
    expect(find.text('Cerrar sesión'), findsNothing);
  });

  testWidgets('a probe that never answered guesses at neither',
      (WidgetTester tester) async {
    await signIn(
      tester,
      link: () => const LinkConflict('one of the two'),
      probe: () => const MeUnreachable('no route to host'),
    );

    expect(find.textContaining('no van juntos'), findsOneWidget);
    expect(find.textContaining('otro teléfono'), findsNothing);
    expect(find.textContaining('otra cuenta'), findsNothing);
    // Asking again is the one thing that could answer differently.
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('a link that succeeds asks nothing extra', (WidgetTester tester) async {
    // The probe is the conflict path's alone. `POST /players/link` already
    // answers the frozen `Me`, so a second round trip on the happy path would
    // be the same question twice.
    await signIn(
      tester,
      link: () => LinkDone(_profile(_devicePlayer)),
      probe: () => const MeNoPlayer(),
    );

    expect(probed, isEmpty);
    expect(find.textContaining('Tus retos se guardan'), findsOneWidget);
  });

  testWidgets('a conflict never opens the erasure door', (WidgetTester tester) async {
    // Load-bearing in both directions. With no player under this account
    // `DELETE /me` answers 404, which the flow reads as *"Listo, ya no queda
    // nada"* — a second lie; and where the account *does* have a player, the
    // row it would erase is the other device's.
    for (final AccountState state in <AccountState>[
      AccountState.otherAccount,
      AccountState.otherDevice,
      AccountState.mismatch,
    ]) {
      expect(erasureOffered(state), isFalse, reason: state.name);
    }
  });
}
