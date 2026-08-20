import 'dart:async';

import 'package:akimath_app/api/history.dart';
import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/features/account/policy/session.dart';
import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/progress/ui/progress_route.dart';
import 'package:flutter/material.dart';
import 'package:akimath_app/api/me.dart';
import 'package:flutter_test/flutter_test.dart';

const LinkedSession _session = LinkedSession(
  email: 'alguien@ejemplo.com',
  accessToken: 'a.bearer.token',
  ageBand: AgeBand.adult,
);

HistoryEntry _entry() => HistoryEntry(
  kind: HistoryKind.series,
  title: 'Restas',
  at: DateTime.utc(2026, 8, 19, 15),
  score: '4/5',
  ratingDelta: null,
);

void main() {
  late List<String> asked;

  Future<void> pump(
    WidgetTester tester, {
    LinkedSession? session,
    Future<HistoryResult> Function(String)? fetch,
  }) async {
    asked = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: ProgressRoute(
        session: session,
        dayLog: InMemoryDayLogStore(),
        now: () => DateTime.utc(2026, 8, 19),
        fetchHistory: (String token) {
          asked.add(token);
          return fetch?.call(token) ??
              Future<HistoryResult>.value(HistoryFound(History(<HistoryEntry>[_entry()])));
        },
      ),
    ));
    await tester.pump();
  }

  testWidgets('with no session it asks nothing and still shows the figures',
      (WidgetTester tester) async {
    // A phone that never linked knows what it did. Asking would be a request
    // with no credential and a wait for an answer nobody can give.
    await pump(tester);
    await tester.pumpAndSettle();

    expect(asked, isEmpty);
    // No section either: a `HISTORIAL` nothing can ever fill is a promise.
    expect(find.text('HISTORIAL'), findsNothing);
    expect(find.text('DÍAS'), findsOneWidget);
  });

  testWidgets('with one it asks once, waits, then shows what came back',
      (WidgetTester tester) async {
    final Completer<HistoryResult> answer = Completer<HistoryResult>();
    await pump(tester, session: _session, fetch: (_) => answer.future);

    expect(asked, <String>['a.bearer.token']);
    expect(find.byKey(const Key('history-loading')), findsOneWidget);

    answer.complete(HistoryFound(History(<HistoryEntry>[_entry()])));
    await tester.pumpAndSettle();

    expect(find.text('Restas'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
  });

  testWidgets('a session arriving later is asked about', (WidgetTester tester) async {
    // The player signs in on `Ajustes` while this root is already built —
    // `IndexedStack` keeps it alive, so it is not rebuilt from scratch.
    await pump(tester);
    await tester.pumpAndSettle();
    expect(asked, isEmpty);

    await tester.pumpWidget(MaterialApp(
      home: ProgressRoute(
        session: _session,
        dayLog: InMemoryDayLogStore(),
        now: () => DateTime.utc(2026, 8, 19),
        fetchHistory: (String token) {
          asked.add(token);
          return Future<HistoryResult>.value(
            HistoryFound(History(<HistoryEntry>[_entry()])),
          );
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(asked, <String>['a.bearer.token']);
    expect(find.text('Restas'), findsOneWidget);
  });

  testWidgets('a failure can be retried, and the second answer replaces the first',
      (WidgetTester tester) async {
    int calls = 0;
    await pump(
      tester,
      session: _session,
      fetch: (_) async {
        calls += 1;
        return calls == 1
            ? const HistoryUnreachable('no route')
            : HistoryFound(History(<HistoryEntry>[_entry()]));
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Restas'), findsOneWidget);
  });

  testWidgets('an answer arriving after the route is gone changes nothing',
      (WidgetTester tester) async {
    final Completer<HistoryResult> answer = Completer<HistoryResult>();
    await pump(tester, session: _session, fetch: (_) => answer.future);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    answer.complete(HistoryFound(History(<HistoryEntry>[_entry()])));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
