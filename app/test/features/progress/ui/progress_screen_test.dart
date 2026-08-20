import 'package:akimath_app/api/history.dart';
import 'package:akimath_app/features/progress/policy/progress_view.dart';
import 'package:akimath_app/features/progress/ui/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEntry _entry({String title = 'Restas', String score = '4/5', int day = 19}) =>
    HistoryEntry(
      kind: HistoryKind.series,
      title: title,
      at: DateTime.utc(2026, 8, day, 15),
      score: score,
      ratingDelta: null,
    );

Future<void> _pump(
  WidgetTester tester, {
  int daysPractised = 12,
  int streakDays = 5,
  HistoryState historyState = HistoryState.noAccount,
  List<HistoryEntry> entries = const <HistoryEntry>[],
  VoidCallback? onRetryHistory,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ProgressScreen(
        daysPractised: daysPractised,
        streakDays: streakDays,
        historyState: historyState,
        entries: entries,
        onRetryHistory: onRetryHistory,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('the figures the device knows', () {
    testWidgets('are there whatever the server says', (WidgetTester tester) async {
      // A phone that has never synced still knows what it did, so the left half
      // does not depend on the right one.
      for (final HistoryState state in HistoryState.values) {
        await _pump(tester, historyState: state);
        expect(find.text('12'), findsOneWidget, reason: state.name);
        expect(find.text('5'), findsOneWidget, reason: state.name);
      }
    });

    testWidgets('and a player who has never played still gets a screen',
        (WidgetTester tester) async {
      await _pump(tester, daysPractised: 0, streakDays: 0);
      expect(find.text('0'), findsNWidgets(2));
    });
  });

  group('the history the server knows', () {
    testWidgets('a session reads as what it was, how it went and when',
        (WidgetTester tester) async {
      await _pump(
        tester,
        historyState: HistoryState.ready,
        entries: <HistoryEntry>[_entry()],
      );

      expect(find.text('Restas'), findsOneWidget);
      expect(find.text('4/5'), findsOneWidget);
      expect(find.textContaining('ago'), findsOneWidget);
    });

    testWidgets('and the order is the one it arrived in', (WidgetTester tester) async {
      // Newest first is the server's decision; a screen re-sorting would
      // diverge the day two sessions share an instant.
      await _pump(
        tester,
        historyState: HistoryState.ready,
        entries: <HistoryEntry>[
          _entry(title: 'segunda', day: 19),
          _entry(title: 'primera', day: 18),
        ],
      );

      final double second = tester.getTopLeft(find.text('segunda')).dy;
      final double first = tester.getTopLeft(find.text('primera')).dy;
      expect(second, lessThan(first));
    });

    testWidgets('waiting is skeletons, never a spinner', (WidgetTester tester) async {
      await _pump(tester, historyState: HistoryState.loading);

      expect(find.byKey(const Key('history-loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('an empty history is told, not apologised for',
        (WidgetTester tester) async {
      await _pump(tester, historyState: HistoryState.empty);

      expect(find.byKey(const Key('history-note')), findsOneWidget);
      expect(find.byKey(const Key('history-banner')), findsNothing);
      expect(find.text(historyMessage(HistoryState.empty)!), findsOneWidget);
    });

    testWidgets('and so is having no account at all', (WidgetTester tester) async {
      await _pump(tester, historyState: HistoryState.noAccount);

      expect(find.byKey(const Key('history-note')), findsOneWidget);
      expect(find.textContaining('Crea una cuenta'), findsOneWidget);
    });

    testWidgets('the states somebody has to act on get a banner',
        (WidgetTester tester) async {
      for (final HistoryState state in <HistoryState>[
        HistoryState.offline,
        HistoryState.serverError,
        HistoryState.rejected,
      ]) {
        await _pump(tester, historyState: state);
        expect(find.byKey(const Key('history-banner')), findsOneWidget, reason: state.name);
      }
    });

    testWidgets('a retry appears only where it could change the answer',
        (WidgetTester tester) async {
      for (final HistoryState state in HistoryState.values) {
        await _pump(tester, historyState: state, onRetryHistory: () {});
        expect(
          find.text('Reintentar'),
          canRetryHistory(state) ? findsOneWidget : findsNothing,
          reason: state.name,
        );
      }
    });
  });

  group('what it deliberately does not print', () {
    testWidgets('no rating, no delta, no accuracy', (WidgetTester tester) async {
      // All three are F4's. `ratingDelta` comes back null from a server with no
      // rating, and a dash where a number will go is a promise this screen
      // cannot keep yet.
      await _pump(
        tester,
        historyState: HistoryState.ready,
        entries: <HistoryEntry>[_entry()],
      );

      final List<String> copy = tester
          .widgetList<Text>(find.byType(Text))
          .map((Text t) => t.data ?? '')
          .toList();

      for (final String forbidden in <String>['Rating', 'rating', 'Precisión', '±', 'ELO']) {
        expect(copy.any((String s) => s.contains(forbidden)), isFalse, reason: forbidden);
      }
    });
  });
}
