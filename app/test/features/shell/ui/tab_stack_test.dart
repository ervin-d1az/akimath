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
  testWidgets('a changed root reaches the screen the tab is showing',
      (WidgetTester tester) async {
    // **The shell could not hand a root anything after the first frame.**
    // `onGenerateRoute` runs once, `_ModalScope` caches the page it built, and
    // the `pageBuilder` closure captured whichever `child` the first build
    // passed — so every later `RootScaffold.setState` produced a `ProfileRoute`
    // that was never mounted. The session and the visibility signal both travel
    // this way, which is why a sign-in changed nothing on screen.
    await tester.pumpWidget(host(const Text('antes')));
    expect(find.text('antes'), findsOneWidget);

    await tester.pumpWidget(host(const Text('después')));
    await tester.pumpAndSettle();

    expect(find.text('después'), findsOneWidget);
    expect(find.text('antes'), findsNothing);
  });

  testWidgets('and a screen pushed over it is not disturbed by that',
      (WidgetTester tester) async {
    // The root updating must not rebuild or replace the stack above it: a
    // settings screen that vanished when the shell rebuilt would be worse than
    // the staleness this fixes.
    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext inner) => TextButton(
            onPressed: () => Navigator.of(inner).push(
              MaterialPageRoute<void>(builder: (_) => const Text('empujada')),
            ),
            child: const Text('antes'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('antes'));
    await tester.pumpAndSettle();
    expect(find.text('empujada'), findsOneWidget);

    await tester.pumpWidget(host(const Text('después')));
    await tester.pumpAndSettle();

    expect(find.text('empujada'), findsOneWidget, reason: 'the stack was lost');
  });

  testWidgets('a root keeps its state while a changed field reaches it',
      (WidgetTester tester) async {
    // **Both halves matter, and they pull against each other.** The field has
    // to arrive — this is how `RootScaffold`'s session reaches a root, and it
    // did not — while the root must *not* be rebuilt from scratch, which is
    // what the shell's `IndexedStack` is for: a home that re-read its pack on
    // every tab switch would flash a skeleton each time.
    _RootWithState.builds = 0;
    await tester.pumpWidget(host(const _RootWithState(label: 'sin cuenta')));
    expect(find.text('sin cuenta'), findsOneWidget);
    expect(_RootWithState.builds, 1);

    await tester.pumpWidget(host(const _RootWithState(label: 'ana@correo.mx')));
    await tester.pumpAndSettle();

    expect(find.text('ana@correo.mx'), findsOneWidget,
        reason: 'the shell cannot hand a root anything after the first frame');
    expect(_RootWithState.builds, 1,
        reason: 'the root was thrown away and built again');
  });

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

/// A root that says how many times it was created, and what it was last told.
///
/// `initState` counts creations rather than builds: the question is whether the
/// element survived, not how often it painted.
class _RootWithState extends StatefulWidget {
  const _RootWithState({required this.label});

  final String label;

  static int builds = 0;

  @override
  State<_RootWithState> createState() => _RootWithStateState();
}

class _RootWithStateState extends State<_RootWithState> {
  @override
  void initState() {
    super.initState();
    _RootWithState.builds += 1;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}
