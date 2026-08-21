import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/features/home/data/series_cursor_store.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:akimath_app/features/stats/data/answer_record_store.dart';
import 'package:akimath_app/features/stats/policy/local_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Where each figure on `4.1` comes from.
///
/// **Every figure this screen prints is now the device's own.** Two come from
/// `DayLog`, one from the series cursor, and two — accuracy and mean time —
/// from the record `features/stats/` keeps of what was answered. Nothing here
/// reads `DemoFigures`, and that is the assertion: the screen that used to
/// print `RATING 1 248` and `78 % ACIERTOS` beside a real `0 RETOS` now prints
/// only what happened.
///
/// **The store is the real one, not an injected stand-in.** The round writes
/// through `PrefsAnswerRecordStore` and this route reads through it; a test
/// that handed both halves a fake would pass with the two pointed at different
/// keys, which is the one way this wiring can be wrong.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProfileRoute(
        now: () => DateTime.utc(2026, 8, 20),
        authBaseUrl: '',
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Three right out of four, at four different speeds: 75 % and a mean of
  /// 6,5 s — both deliberately unlike the 78 % and 6,8 s the demo drew, so a
  /// route still reading those constants fails rather than agreeing by
  /// accident.
  Future<void> answerFourItems() async {
    const AnswerRecordStore store = PrefsAnswerRecordStore();
    for (final List<int> answer in <List<int>>[
      <int>[1, 5000],
      <int>[1, 6000],
      <int>[1, 7000],
      <int>[0, 8000],
    ]) {
      await store.record(AnsweredItem(
        verdict: answer.first == 1 ? Verdict.correct : Verdict.wrong,
        elapsed: Duration(milliseconds: answer.last),
      ));
    }
  }

  testWidgets('the count of challenges is the one the home recorded',
      (WidgetTester tester) async {
    // `RETOS` is a real figure: the series cursor is a persisted running total
    // across every session, advanced when a series finishes. A phone that has
    // never synced still knows it.
    await SharedPreferencesAsync().setInt(SeriesCursorStore.key, 312);

    await pump(tester);

    expect(find.text('RETOS'), findsOneWidget);
    expect(find.text(EsMxNumber.integer(312)), findsOneWidget);
  });

  testWidgets('accuracy and mean time are what this device answered',
      (WidgetTester tester) async {
    await answerFourItems();

    await pump(tester);

    expect(find.text('ACIERTOS'), findsOneWidget);
    expect(find.text(EsMxNumber.percent(75)), findsOneWidget);
    expect(find.text('PROMEDIO'), findsOneWidget);
    expect(find.text(EsMxNumber.seconds(6.5, places: 1)), findsOneWidget);
  });

  testWidgets('a device that has answered nothing draws neither tile',
      (WidgetTester tester) async {
    // **Absent, not zero.** `0 %` is a claim about a player who has answered
    // nothing and it is false — it says they got everything wrong. Same
    // reading `HISTORIAL` takes when there is nothing true to say.
    await pump(tester);

    expect(find.text('RETOS'), findsOneWidget,
        reason: 'the count is the device own and always known');
    expect(find.text('ACIERTOS'), findsNothing);
    expect(find.text('PROMEDIO'), findsNothing);
    expect(find.text(EsMxNumber.percent(0)), findsNothing);
  });

  testWidgets('no rating is drawn, because there is no one number to draw',
      (WidgetTester tester) async {
    // `GET /me/standing` answers a rating *per skill*. There is no single
    // number on the wire, this client cannot even name a skill — `skillId` is
    // an integer and `skillName()` lives server-side in `@akimath/core` — and
    // `api/standing.dart` forbids arithmetic over the ratings in writing. So
    // the lead card is the days, which is a figure the device can prove.
    await answerFourItems();

    await pump(tester);

    expect(find.text('RATING'), findsNothing);
    expect(find.textContaining('esta semana'), findsNothing);
    expect(find.text('DÍAS'), findsOneWidget);
  });
}
