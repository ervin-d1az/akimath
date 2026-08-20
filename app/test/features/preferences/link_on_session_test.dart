import 'dart:async';

import 'package:akimath_app/api/api_client.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/account/data/player_id_store.dart';
import 'package:akimath_app/features/account/policy/player_id.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/preferences/ui/preferences_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The device attaches its player as soon as it has a session.
///
/// **This exists because nothing did it.** The app created a Neon Auth account
/// and asked `GET /me`, and never called `POST /players/link` — so the server
/// had an account with no player, `GET /me` answered 404 for ever, and every
/// operation built on top of it was unreachable. The account section drew
/// *"Cuenta lista. Falta vincular un jugador"* and there was no way to.
const LinkedSession _session = LinkedSession(
  email: 'alguien@ejemplo.com',
  accessToken: 'a.bearer.token',
  ageBand: AgeBand.under13,
);

Me _me() => Me(
  playerId: '018f4e3c-0000-7000-8000-0000000000b1',
  ageBand: AgeBand.under13,
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
      home: PreferencesRoute(
        session: session,
        playerIds: InMemoryPlayerIdStore(),
        authBaseUrl: 'https://auth.example/neondb/auth',
        now: () => DateTime.utc(2026, 8, 19),
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

  testWidgets('with one it links, carrying the band the gate resolved',
      (WidgetTester tester) async {
    // The band is not read off the account: linking is an adult's act but the
    // player need not be an adult, and taking `adult` off the credential would
    // route a child out of their own protections.
    await pump(tester, session: _session);
    await tester.pumpAndSettle();

    expect(asked, hasLength(1));
    expect(asked.single.token, 'a.bearer.token');
    expect(asked.single.band, AgeBand.under13);
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

  testWidgets('an account already used on another phone says so and stops',
      (WidgetTester tester) async {
    // One account, one player (migration 0003). Which phone it belongs to is a
    // choice nobody has designed, so the app says what is true and offers
    // nothing it cannot do.
    await pump(
      tester,
      session: _session,
      answer: () async => const LinkConflict('this account already has a player'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('otro teléfono'), findsOneWidget);
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
