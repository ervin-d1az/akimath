import 'dart:async';

import 'package:akimath_app/api/api_client.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/account/data/player_id_store.dart';
import 'package:akimath_app/features/account/policy/player_id.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The device attaches its player as soon as it has a session.
///
/// **This exists because nothing did it.** The app created a Neon Auth account
/// and asked `GET /me`, and never called `POST /players/link` — so the server
/// had an account with no player, `GET /me` answered 404 for ever, and every
/// operation built on top of it was unreachable. The account section drew
/// *"Cuenta lista. Falta vincular un jugador"* and there was no way to.
///
/// **The band is `13_17` deliberately, and it is not the one this build's gate
/// can produce.** It is a *probe*: the claim under test is that whatever band
/// the session holds is the band the request carries, and after ADR 0004 an
/// `adult` fixture would be satisfied by a `?? adult` default as well as by the
/// real thing (PROC-11's fifth bullet). `13_17` is also the one non-adult value
/// a real session could historically hold — it reached the account form until
/// ADR 0004 and the frozen `CHECK` still permits it — so this is a reachable
/// state rather than an invented one.
///
/// **What this file does *not* assert is that such a session should link**, and
/// that is a residual rather than a decision. `ProfileRoute` passes a band
/// through; the judging is `AuthFlow`'s, where both sources of a band meet
/// `AgeGate.next`. A session restored from disk on a device that linked as
/// `13_17` before this change reaches here without passing that gate.
const LinkedSession _session = LinkedSession(
  email: 'alguien@ejemplo.com',
  accessToken: 'a.bearer.token',
  ageBand: AgeBand.thirteenToSeventeen,
);

Me _me() => Me(
  playerId: '018f4e3c-0000-7000-8000-0000000000b1',
  ageBand: AgeBand.thirteenToSeventeen,
  createdAt: DateTime.utc(2026, 8, 19),
);

void main() {
  late List<({String token, String playerId, AgeBand band})> asked;

  Future<void> pump(
    WidgetTester tester, {
    LinkedSession? session,
    Future<LinkResult> Function()? answer,
  }) async {
    asked = <({String token, String playerId, AgeBand band})>[];
    await tester.pumpWidget(MaterialApp(
      home: ProfileRoute(
        session: session,
        playerIds: InMemoryPlayerIdStore(),
        authBaseUrl: 'https://auth.example/neondb/auth',
        now: () => DateTime.utc(2026, 8, 19),
        // **Injected so no test here opens a socket.** A 409 sends the route
        // off to ask `GET /me` which conflict it was; left to the default that
        // question would travel for real.
        whoAmI: (String accessToken) async => const MeUnreachable('no route'),
        link: ({
          required String accessToken,
          required String playerId,
          required AgeBand ageBand,
        }) {
          asked.add((token: accessToken, playerId: playerId, band: ageBand));
          return answer?.call() ?? Future<LinkResult>.value(LinkDone(_me()));
        },
      ),
    ));
    await tester.pump();
  }

  testWidgets('with no session it asks nothing', (WidgetTester tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(asked, isEmpty);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets('with one it links, carrying the band the session holds',
      (WidgetTester tester) async {
    // **The band is the session's, never the credential's and never a
    // default.** A `?? adult` here would be the app asserting an age nobody
    // declared, which is the one thing the field exists to prevent — and it is
    // what the non-adult probe above makes visible.
    await pump(tester, session: _session);
    await tester.pumpAndSettle();

    expect(asked, hasLength(1));
    expect(asked.single.token, 'a.bearer.token');
    expect(asked.single.band, AgeBand.thirteenToSeventeen);
    expect(isPlayerId(asked.single.playerId), isTrue);
  });

  testWidgets('and it links once, not once per rebuild', (WidgetTester tester) async {
    await pump(tester, session: _session);
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(asked, hasLength(1));
  });

  testWidgets('a session that already has this device´s player is linked',
      (WidgetTester tester) async {
    // Idempotent by nature: the row it would write is the row already there.
    // A returning device re-attaches rather than needing to remember whether it
    // linked before.
    await pump(tester, session: _session);
    await tester.pumpAndSettle();

    expect(find.text('alguien@ejemplo.com'), findsOneWidget);
    expect(find.textContaining('Tus retos se guardan'), findsOneWidget);
  });

  testWidgets('a refused link claims only what the 409 actually said',
      (WidgetTester tester) async {
    // **It used to say *"otro teléfono"* here, and on a real device that was
    // false.** Two conflicts land on one 409 — the account already has a
    // player, or this device's player already has an account — and the wire
    // tells them apart only in an English `message`. With no probe answer this
    // route names neither. Which way round it runs, and the door that follows,
    // are `test/features/profile/ui/account_conflict_test.dart`.
    await pump(
      tester,
      session: _session,
      answer: () async => const LinkConflict('this account already has a player'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('no van juntos'), findsOneWidget);
    expect(find.textContaining('otro teléfono'), findsNothing);
  });

  testWidgets('no answer at all is offline, and not the player´s fault',
      (WidgetTester tester) async {
    await pump(
      tester,
      session: _session,
      answer: () async => const LinkUnreachable('no route'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-banner')), findsOneWidget);
  });

  testWidgets('and an answer arriving after the route is gone changes nothing',
      (WidgetTester tester) async {
    final Completer<LinkResult> answer = Completer<LinkResult>();
    await pump(tester, session: _session, answer: () => answer.future);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    answer.complete(LinkDone(_me()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
