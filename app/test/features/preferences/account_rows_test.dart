import 'package:akimath_app/api/history.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/preferences/ui/account_screen.dart';
import 'package:akimath_app/features/preferences/ui/change_password_screen.dart';
import 'package:akimath_app/features/preferences/ui/settings_list_screen.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:akimath_app/features/profile/ui/profile_screen.dart';
import 'package:akimath_app/features/shell/ui/tab_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether a player can **reach** the two rows `4.3 Cuenta` draws.
///
/// **`AccountScreen` has drawn them since it landed and nothing passed the
/// callbacks**, so both were absent by the screen's own rule — a row is drawn
/// where its caller hands one and absent where it does not (DR-P2). Pumping
/// the screen with the callbacks proves the rows render; it proves nothing
/// about whether anybody can get to them, which is what was actually broken.
/// So this walks Perfil → Ajustes → Cuenta.
class _Shell extends StatefulWidget {
  const _Shell({required this.session});

  final LinkedSession session;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late LinkedSession? _session = widget.session;

  /// What the shell was told, so a test reads the sign-out rather than infers
  /// it from a screen.
  int forgotten = 0;

  @override
  Widget build(BuildContext context) => ProfileRoute(
        session: _session,
        onSessionChanged: (LinkedSession? session) {
          if (session == null) {
            forgotten += 1;
          }
          setState(() => _session = session);
        },
        now: () => DateTime.utc(2026, 8, 20),
        authBaseUrl: 'https://auth.example/neondb/auth',
        whoAmI: (String token) async => MeFound(Me(
          playerId: '8f14e45f-ceea-4167-a5b0-9c0e2f3a1b2c',
          ageBand: AgeBand.adult,
          createdAt: DateTime.utc(2026, 8, 1),
        )),
        link: ({
          required String accessToken,
          required String playerId,
          required AgeBand ageBand,
        }) async =>
            LinkDone(Me(
          playerId: playerId,
          ageBand: ageBand,
          createdAt: DateTime.utc(2026, 8, 20),
        )),
        fetchHistory: (String accessToken) async =>
            const HistoryFound(History(<HistoryEntry>[])),
      );
}

Future<_ShellState> _openCuenta(
  WidgetTester tester, {
  bool insideATabStack = false,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  const Widget shellUnderTest = _Shell(
    session: LinkedSession(
      email: 'ana@correo.mx',
      accessToken: 'header.payload.signature',
      ageBand: AgeBand.adult,
    ),
  );
  await tester.pumpWidget(MaterialApp(
    home: insideATabStack
        // **The navigator the app really uses.** Every push here lands on the
        // tab's own `pages:` Navigator rather than the app's, and `_signOut`
        // pops until `route.isFirst` — so this is the one place the two halves
        // of this change meet.
        ? const TabStack(child: shellUnderTest)
        : shellUnderTest,
  ));
  await tester.pumpAndSettle();

  // Read before navigating: a pushed route covers the shell, and a covered
  // subtree is offstage to the default finder.
  final _ShellState shell = tester.state<_ShellState>(find.byType(_Shell));

  await tester.tap(find.bySemanticsLabel('Ajustes'));
  await tester.pumpAndSettle();
  expect(find.byType(SettingsListScreen), findsOneWidget);

  await tester.tap(find.text('Cuenta'));
  await tester.pumpAndSettle();
  expect(find.byType(AccountScreen), findsOneWidget);

  return shell;
}

void main() {
  testWidgets('Cambiar contraseña is reachable and opens the screen behind it',
      (WidgetTester tester) async {
    await _openCuenta(tester);

    expect(find.text('Cambiar contraseña'), findsOneWidget);

    await tester.tap(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(find.text(changePasswordHeadline), findsOneWidget);
  });

  testWidgets('Cerrar sesión forgets the session the shell is holding',
      (WidgetTester tester) async {
    // **The shell owns it**, so a sign-out that only cleared this route's own
    // state would leave the home still syncing under a token the player asked
    // us to drop. `onSessionChanged(null)` is the only thing that forgets it,
    // and it is the same pair the erasure success path already runs.
    final _ShellState shell = await _openCuenta(tester);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(shell.forgotten, 1);
    // Back on the profile root, not left inside the account's own stack: the
    // player asked to leave the account, and `4.3` has nothing left to show.
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(AccountScreen), findsNothing);
    expect(find.byType(SettingsListScreen), findsNothing);
    // Signed out, so the doors are back and the address is gone.
    expect(find.text('ana@correo.mx'), findsNothing);
    expect(find.text('Ya tengo cuenta'), findsOneWidget);
  });

  testWidgets('and it pops the tab\'s own stack, not the app\'s',
      (WidgetTester tester) async {
    // `_signOut` pops until `route.isFirst`, and in the app that first route is
    // the page-managed root `TabStack` declares rather than a pushed one. The
    // other cases here pump the route straight under `MaterialApp`, where the
    // pop resolves to the app's navigator — so without this the interaction
    // between the two halves of this change is never exercised.
    final _ShellState shell = await _openCuenta(tester, insideATabStack: true);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(shell.forgotten, 1);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(AccountScreen), findsNothing);
    expect(find.byType(SettingsListScreen), findsNothing);
  });

  testWidgets('and nothing this device recorded is dropped with it',
      (WidgetTester tester) async {
    // **Sign-out is not erasure**, and this is the assertion that keeps them
    // apart. Unlinked play is entirely offline (ADR 0002), so the days
    // practised, the run and the challenge count belong to a player who never
    // had an account at all — a row labelled *Cerrar sesión* that deleted them
    // would be a destructive act wearing a non-destructive label. The
    // destructive door is `Eliminar mi cuenta`, with a typed `BORRAR` gate.
    final _ShellState shell = await _openCuenta(tester);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(shell.forgotten, 1);
    expect(find.text('RACHA'), findsOneWidget);
    expect(find.text('RETOS'), findsOneWidget);
  });
}
