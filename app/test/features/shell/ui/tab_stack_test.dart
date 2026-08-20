import 'package:akimath_app/features/shell/ui/tab_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tab keeps its own stack, and the bar stays under it.
///
/// **Found on a device, not in a suite.** The settings list pushed onto the
/// app's root navigator, which covers the whole `Scaffold` — bar included. The
/// design says the opposite: the group badge over `4.1`–`4.7` reads *"Aquí sí
/// va la barra inferior"*, because the stack sits **above a home** rather than
/// replacing it.
Widget host(Widget child, {GlobalKey<NavigatorState>? key}) => MaterialApp(
      home: Scaffold(
        body: TabStack(navigatorKey: key, child: child),
        bottomNavigationBar: const SizedBox(height: 72, child: Text('barra')),
      ),
    );

void main() {
  testWidgets('a push inside a tab leaves the bar alone', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext inner) => TextButton(
            onPressed: () => Navigator.of(inner).push(
              MaterialPageRoute<void>(builder: (_) => const Text('empujada')),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('empujada'), findsOneWidget);
    expect(find.text('barra'), findsOneWidget, reason: 'the bar left with the push');
  });

  testWidgets('and popping comes back to the root', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext inner) => TextButton(
            onPressed: () => Navigator.of(inner).push(
              MaterialPageRoute<void>(builder: (_) => const Text('empujada')),
            ),
            child: const Text('abrir'),
          ),
        ),
        key: key,
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(key.currentState!.canPop(), isTrue);

    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('abrir'), findsOneWidget);
    expect(key.currentState!.canPop(), isFalse);
  });

  testWidgets('a system back pops the tab before it leaves the app',
      (WidgetTester tester) async {
    // Without this the first back press exits, discarding a stack the player
    // can see. Android's back is the case; iOS's edge swipe is handled by the
    // inner navigator itself.
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext inner) => TextButton(
            onPressed: () => Navigator.of(inner).push(
              MaterialPageRoute<void>(builder: (_) => const Text('empujada')),
            ),
            child: const Text('abrir'),
          ),
        ),
        key: key,
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final bool handled = await TabStack.popTab(key);
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('abrir'), findsOneWidget);

    // At the root there is nothing to pop, and the app may leave.
    expect(await TabStack.popTab(key), isFalse);
  });
}
