/// How the shipping app is started, from a device state a suite chose.
///
/// **Two doors, and a suite says which one it is walking through.** Before
/// this, all five suites that launch `main()` opened the same way — a first-run
/// walk behind `if (find.byType(WelcomeScreen).evaluate().isNotEmpty)`, taken or
/// not according to whatever the simulator was already holding. A suite named
/// *"a fresh install …"* therefore made a claim about the device that nothing
/// established and nothing checked.
///
/// A suite about the first run calls [launchOnAFreshInstall], which produces one
/// and fails if the welcome does not appear. A suite about anything else calls
/// [launchOnTheHome] and says so, rather than adapting to the handset.
library;

import 'package:akimath_app/design/widgets/keypad.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/onboarding/ui/calibration_intro_screen.dart';
import 'package:akimath_app/features/onboarding/ui/first_item_screen.dart';
import 'package:akimath_app/features/onboarding/ui/save_progress_screen.dart';
import 'package:akimath_app/features/onboarding/ui/welcome_screen.dart';
import 'package:akimath_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'device_state.dart';

/// How long a settle budget waits between pumps.
///
/// A real device is slower than a widget test and every screen here waits on a
/// preference read or the real asset bundle, so the budgets below settle
/// repeatedly rather than once. `FirstRunGate.splashFloor` alone is 1100 ms.
const Duration _pumpInterval = Duration(milliseconds: 300);

/// How many intervals a screen is given to appear: six seconds.
const int _pumpBudget = 20;

/// How long the launch itself is given, splash floor and first frame included.
const Duration _launchBudget = Duration(seconds: 6);

/// Settles until [finder] matches, or the budget runs out.
///
/// It asserts nothing: the caller does that, so the failure names the screen it
/// was waiting for rather than a helper.
Future<void> _settleUntil(WidgetTester tester, Finder finder) async {
  for (int i = 0; i < _pumpBudget && finder.evaluate().isEmpty; i++) {
    await tester.pumpAndSettle(_pumpInterval);
  }
}

/// Presses the key whose id is [id] on whichever pad is on screen.
///
/// By id and not by the character on the face: `-` is `negate` and `/` is
/// `fraction`, and neither is what a player reads on the key.
Future<void> pressKey(WidgetTester tester, String id) async {
  await tester.tap(
    find.byWidgetPredicate((Widget w) => w is KeypadKeyView && w.data.id == id),
  );
  await tester.pump();
}

/// Starts the app on a device with nothing stored, and walks the first run.
///
/// Every screen of `0.2 → 0.3 → 0.4 → 0.7` is **asserted on the way past**, so a
/// run that silently skipped one fails here instead of leaving a suite to
/// discover the consequence three screens later.
///
/// **The probe is skipped rather than played** (`Saltar por ahora`). Ten
/// measured items in front of every suite would make each failure a failure
/// about something else — and playing them would advance
/// `akimath.items_served.v1`, which is what `playthrough_test`'s claim that ten
/// items cover all six families depends on being zero.
///
/// Leaves the home on screen.
Future<void> launchOnAFreshInstall(WidgetTester tester) async {
  await establish(DeviceState.freshInstall);
  app.main();
  await tester.pumpAndSettle(_launchBudget);

  await _settleUntil(tester, find.byType(WelcomeScreen));
  expect(
    find.byType(WelcomeScreen),
    findsOneWidget,
    reason: 'a fresh install opens on Bienvenida',
  );

  await tester.tap(find.text('Resolver uno'));
  await tester.pumpAndSettle();
  expect(find.byType(FirstItemScreen), findsOneWidget);

  // 5 + 8 = 13, the teaching item. The first run completes when it is solved.
  await pressKey(tester, '1');
  await pressKey(tester, '3');
  await pressKey(tester, 'submit');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Siguiente'));

  // **`0.4` is reached, not merely allowed for.** `OnboardingFlow` reads the
  // pack in `initState` and `_afterTeachingItem` branches on `_probe.isEmpty`
  // at the moment of the tap above, so a bundle read that had not finished
  // would step over all three probe screens and land on `0.7`. That is a real
  // outcome worth failing on rather than absorbing: a first run that teaches
  // and then measures nothing is not the run the design draws.
  await _settleUntil(tester, find.byType(CalibrationIntroScreen));
  expect(
    find.byType(CalibrationIntroScreen),
    findsOneWidget,
    reason: 'Calibración intro follows the teaching item',
  );
  await tester.tap(find.text('Saltar por ahora'));

  await _settleUntil(tester, find.byType(SaveProgressScreen));
  expect(
    find.byType(SaveProgressScreen),
    findsOneWidget,
    reason: 'Guardar progreso is the last screen of the run',
  );
  await tester.tap(find.text('Después'));

  await _reachTheHome(tester);
}

/// Starts the app on a device whose first run is behind it.
///
/// The welcome is **asserted absent**: this is the state the suite asked for,
/// and a launch that lands on the onboarding anyway means the seed did not take
/// and everything after it would be measuring the wrong app.
///
/// Leaves the home on screen.
Future<void> launchOnTheHome(WidgetTester tester) async {
  await establish(DeviceState.returningPlayer);
  app.main();
  await tester.pumpAndSettle(_launchBudget);

  await _reachTheHome(tester);
  expect(
    find.byType(WelcomeScreen),
    findsNothing,
    reason: 'a returning player does not meet the first run again',
  );
}

/// Waits for the home and says what was there instead when it never came.
Future<void> _reachTheHome(WidgetTester tester) async {
  await _settleUntil(tester, find.byType(HomeScreen));
  expect(
    find.byType(HomeScreen),
    findsOneWidget,
    reason: 'never reached the home; on screen instead: ${_onScreen(tester)}',
  );
}

/// Every non-empty string the device is currently showing.
///
/// Folded into the failure's own `reason` rather than printed: a diagnostic
/// that reaches the console but not the report is one a CI log buries.
String _onScreen(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => s.isNotEmpty)
    .join(' | ');
