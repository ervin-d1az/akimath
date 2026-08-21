import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/policy/day_log.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
import 'package:akimath_app/features/stats/data/answer_record_store.dart';
import 'package:akimath_app/features/stats/policy/local_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the profile's own figures move while the app stays open.
///
/// **Measured on a device, all at the same moment after one solved item**: the
/// verdict screen said `RACHA 1`, the home said `RACHA 1 DÍA`, and Perfil said
/// `RACHA 0 / días seguidos`. A relaunch fixed it, which is what makes it
/// staleness rather than two screens counting different things.
///
/// The cause is structural: `RootScaffold` keeps every root alive in an
/// `IndexedStack`, so `initState` runs once per launch and a figure read only
/// there is a figure from launch time. There is no second `initState` to hook,
/// so the moment to re-read is the moment the root comes to the front.
class _Harness extends StatefulWidget {
  const _Harness({required this.dayLog, required this.today, this.answers});

  final DayLogStore dayLog;
  final AnswerRecordStore? answers;
  final DateTime today;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  RootVisibility _visibility = RootVisibility.behind;

  void comeToTheFront() =>
      setState(() => _visibility = RootVisibility.showing);

  @override
  Widget build(BuildContext context) => ProfileRoute(
        visibility: _visibility,
        dayLog: widget.dayLog,
        answerRecord: widget.answers,
        now: () => widget.today,
        authBaseUrl: '',
      );
}

void main() {
  final DateTime today = DateTime.utc(2026, 8, 20);

  testWidgets('a day recorded elsewhere shows the next time Perfil is opened',
      (WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final InMemoryDayLogStore log = InMemoryDayLogStore();
    await tester.pumpWidget(
      MaterialApp(home: _Harness(dayLog: log, today: today)),
    );
    await tester.pumpAndSettle();

    expect(find.text('días seguidos'), findsOneWidget,
        reason: 'nothing has been solved yet');

    // What the home does when the player answers. The store is the source of
    // truth; this screen holds only what it last read.
    await log.record(today);
    tester.state<_HarnessState>(find.byType(_Harness)).comeToTheFront();
    await tester.pumpAndSettle();

    expect(find.text('día seguido'), findsOneWidget,
        reason: 'Perfil is still showing the figures it read at launch');
  });

  testWidgets('an answer given elsewhere brings both tiles with it',
      (WidgetTester tester) async {
    // **The second source with the same shape (PROC-13).** The round records
    // into the answer store while Perfil sits behind an `IndexedStack`, so a
    // record read once in `initState` is an accuracy from launch time — the
    // defect the day log already had, arriving by another road.
    //
    // **Two pumps, and the tiles are *absent* on the first.** A player who has
    // answered nothing gets no `ACIERTOS` and no `PROMEDIO` rather than `0 %`,
    // so this checks the appearing of a tile and not merely a number changing
    // — one run covering the refresh path and the absent-not-zero rule.
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final InMemoryAnswerRecordStore answers = InMemoryAnswerRecordStore();
    await tester.pumpWidget(MaterialApp(
      home: _Harness(
        dayLog: InMemoryDayLogStore(),
        today: today,
        answers: answers,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ACIERTOS'), findsNothing);
    expect(find.text('PROMEDIO'), findsNothing);

    // One right answer in four seconds: 100 % and 4,0 s.
    await answers.record(const AnsweredItem(
      verdict: Verdict.correct,
      elapsed: Duration(seconds: 4),
    ));
    tester.state<_HarnessState>(find.byType(_Harness)).comeToTheFront();
    await tester.pumpAndSettle();

    expect(find.text('ACIERTOS'), findsOneWidget,
        reason: 'Perfil is still showing the record it read at launch');
    expect(find.text(EsMxNumber.percent(100)), findsOneWidget);
    expect(find.text('PROMEDIO'), findsOneWidget);
    expect(find.text(EsMxNumber.seconds(4, places: 1)), findsOneWidget);
  });

  testWidgets('and it does not re-read while it is behind',
      (WidgetTester tester) async {
    // **A rebuild is not a visit.** The shell rebuilds every root on every tab
    // switch, so re-reading on any rebuild would read the store for a screen
    // nobody is looking at — and would make the test above pass for the wrong
    // reason.
    final _CountingStore log = _CountingStore();
    await tester.pumpWidget(
      MaterialApp(home: _Harness(dayLog: log, today: today)),
    );
    await tester.pumpAndSettle();

    final int atLaunch = log.reads;
    expect(atLaunch, greaterThan(0), reason: 'it never read at all');

    // A rebuild with the root still behind.
    await tester.pumpWidget(
      MaterialApp(home: _Harness(dayLog: log, today: today)),
    );
    await tester.pumpAndSettle();
    expect(log.reads, atLaunch);

    tester.state<_HarnessState>(find.byType(_Harness)).comeToTheFront();
    await tester.pumpAndSettle();
    expect(log.reads, atLaunch + 1);
  });
}

/// A store that says how often it was asked.
class _CountingStore implements DayLogStore {
  int reads = 0;
  DayLog _log = DayLog.empty;

  @override
  Future<DayLog> read() async {
    reads += 1;
    return _log;
  }

  @override
  Future<DayLog> record(DateTime moment) async {
    _log = _log.recording(moment);
    return _log;
  }
}
