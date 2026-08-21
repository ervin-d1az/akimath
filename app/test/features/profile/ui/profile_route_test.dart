import 'package:akimath_app/demo/demo_figures.dart';
import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/features/home/data/series_cursor_store.dart';
import 'package:akimath_app/features/profile/ui/profile_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Where each figure on `4.1` comes from.
///
/// **The seam the demo hangs on.** Two of the five figures are the device's own
/// and three are invented; this is the one place both are read, so it is the
/// one place that can say which is which. The day a real accuracy lands, the
/// line here changes and nothing else does.
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

  testWidgets('the invented figures come from the one file that holds them',
      (WidgetTester tester) async {
    // Rating, accuracy and mean time have no on-device source. They enter here
    // and nowhere else, so deleting `DemoFigures` is a compile error in one
    // file rather than a hunt. Flipping `enabled` turns this test red, which is
    // the point: it is a deliberate act with a visible consequence.
    await pump(tester);

    expect(find.text(EsMxNumber.integer(DemoFigures.rating)), findsOneWidget);
    expect(
      find.text(EsMxNumber.percent(DemoFigures.accuracyPercent)),
      findsOneWidget,
    );
    expect(
      find.text(EsMxNumber.seconds(
        DemoFigures.averageTenthsOfSecond / 10,
        places: 1,
      )),
      findsOneWidget,
    );
  });
}
