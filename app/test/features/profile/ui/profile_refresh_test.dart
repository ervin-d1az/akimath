import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/policy/day_log.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
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
  const _Harness({required this.dayLog, required this.today});

  final DayLogStore dayLog;
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
