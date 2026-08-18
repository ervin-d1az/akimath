import 'package:akimath_app/features/onboarding/ui/first_run_gate.dart';
import 'package:akimath_app/features/onboarding/ui/welcome_screen.dart';
import 'package:akimath_app/features/splash/splash_screen.dart';
import 'package:akimath_app/features/onboarding/data/onboarding_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A store whose answer the test decides when to give.
class _HeldStore implements OnboardingStore {
  bool answered = false;
  bool complete = false;

  @override
  Future<bool> isComplete() async {
    answered = true;
    return complete;
  }

  @override
  Future<void> markComplete() async {}
}

void main() {
  group('the app opens on the splash and leaves it', () {
    testWidgets('the splash is what a cold start shows',
        (WidgetTester tester) async {
      // **Not `pumpAndSettle`.** Settling runs the gate to completion, which is
      // the state *after* the thing being asserted — the splash would never be
      // observed and the test would pass on an app that never showed it.
      await tester.pumpWidget(
        MaterialApp(
          home: FirstRunGate(
            store: _HeldStore(),
            splashFloor: const Duration(milliseconds: 200),
            home: const Text('home'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('home'), findsNothing);

      // Drained, because the assertion above deliberately lands mid-splash and
      // the binding treats a timer still pending at teardown as a failure.
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('it is the brand-green treatment', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FirstRunGate(
            store: _HeldStore(),
            splashFloor: const Duration(milliseconds: 200),
            home: const Text('home'),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<SplashScreen>(find.byType(SplashScreen)).variant,
        SplashVariant.brandGreen,
      );

      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('no splash remains once startup completes',
        (WidgetTester tester) async {
      // A splash that stays looks deliberate, which is exactly why a failure to
      // advance has to be a visible defect rather than a plausible screen.
      await tester.pumpWidget(
        MaterialApp(
          home: FirstRunGate(
            store: _HeldStore()..complete = true,
            splashFloor: const Duration(milliseconds: 200),
            home: const Text('home'),
          ),
        ),
      );
      // **Pumped past the floor, not merely settled.** `pumpAndSettle` stops
      // when no frame is scheduled, and a pending `Future.delayed` schedules
      // none — so settling alone leaves the fake clock before the floor and
      // observes the splash it was meant to prove had gone.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a first run reaches the welcome, not the home',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FirstRunGate(
            store: _HeldStore(),
            splashFloor: const Duration(milliseconds: 200),
            home: const Text('home'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('the floor holds the splash past the store answering',
        (WidgetTester tester) async {
      // The floor is the whole point: reading one boolean takes milliseconds,
      // and without it the splash is a flicker that reads as a glitch.
      final _HeldStore store = _HeldStore()..complete = true;
      await tester.pumpWidget(
        MaterialApp(
          home: FirstRunGate(
            store: store,
            splashFloor: const Duration(milliseconds: 600),
            home: const Text('home'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(store.answered, isTrue, reason: 'the read should not wait');
      expect(find.byType(SplashScreen), findsOneWidget,
          reason: 'the splash left as soon as the store answered');

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });
}
