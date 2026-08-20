import 'dart:async';

import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/features/preferences/policy/erasure.dart';
import 'package:akimath_app/features/preferences/ui/erase_account_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<bool> closed;

  Future<void> pump(
    WidgetTester tester,
    Future<EraseResult> Function() erase,
  ) async {
    closed = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EraseAccountRoute(
          erase: erase,
          onClose: (bool erased) => closed.add(erased),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('it asks before it sends anything', (WidgetTester tester) async {
    int calls = 0;
    await pump(tester, () async {
      calls++;
      return const EraseDone();
    });

    expect(find.text(erasureConfirmHeadline), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('backing out sends nothing and closes without erasing',
      (WidgetTester tester) async {
    int calls = 0;
    await pump(tester, () async {
      calls++;
      return const EraseDone();
    });

    await tester.tap(find.text(erasureConfirmNo));
    await tester.pump();

    expect(calls, 0);
    expect(closed, <bool>[false]);
  });

  testWidgets('confirming waits, then reports', (WidgetTester tester) async {
    final Completer<EraseResult> answer = Completer<EraseResult>();
    await pump(tester, () => answer.future);

    await tester.tap(find.text(erasureConfirmYes));
    await tester.pump();
    expect(find.text(erasureHeadline(ErasureStep.erasing)), findsOneWidget);
    // Nothing has closed yet: the player has not read the outcome.
    expect(closed, isEmpty);

    answer.complete(const EraseDone());
    await tester.pump();
    expect(find.text(erasureHeadline(ErasureStep.gone)), findsOneWidget);
  });

  testWidgets('and closing after a success says so', (WidgetTester tester) async {
    await pump(tester, () async => const EraseDone());

    await tester.tap(find.text(erasureConfirmYes));
    await tester.pump();
    await tester.tap(find.text('Volver'));
    await tester.pump();

    expect(closed, <bool>[true]);
  });

  testWidgets('a refusal closes without claiming anything was erased',
      (WidgetTester tester) async {
    await pump(
      tester,
      () async => const EraseRejected(tag: 'invalid_session', message: 'caducó'),
    );

    await tester.tap(find.text(erasureConfirmYes));
    await tester.pump();
    await tester.tap(find.text('Volver'));
    await tester.pump();

    expect(closed, <bool>[false]);
  });

  testWidgets('a failure can be retried, and the second answer replaces the first',
      (WidgetTester tester) async {
    int calls = 0;
    await pump(tester, () async {
      calls++;
      return calls == 1 ? const EraseUnreachable('no route') : const EraseDone();
    });

    await tester.tap(find.text(erasureConfirmYes));
    await tester.pump();
    expect(find.text(erasureHeadline(ErasureStep.offline)), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    expect(calls, 2);
    expect(find.text(erasureHeadline(ErasureStep.gone)), findsOneWidget);
  });

  testWidgets('an answer arriving after the flow is gone changes nothing',
      (WidgetTester tester) async {
    // The one crash this route can have: `setState` on a disposed widget. It is
    // reachable — the request outlives the screen whenever a player backs out
    // of a slow erasure.
    final Completer<EraseResult> answer = Completer<EraseResult>();
    await pump(tester, () => answer.future);

    await tester.tap(find.text(erasureConfirmYes));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

    answer.complete(const EraseDone());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
