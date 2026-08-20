import 'package:akimath_app/features/shell/ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A session draws to the device's edges, and the route is what knows it.
///
/// **Found by looking at a device, not by a suite.** Six screens go through
/// `fullScreenSession` and all six carry their own `SafeArea`; the seventh did
/// not, and its Aki sat under the Dynamic Island. Six remembered and one forgot
/// is the definition of a rule that belongs in one place — the same argument
/// `fullScreenSession` itself was extracted for.
void main() {
  testWidgets('a pushed session keeps its content out of the notch',
      (WidgetTester tester) async {
    const EdgeInsets notch = EdgeInsets.only(top: 59, bottom: 34);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: notch),
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                fullScreenSession<void>(
                  (BuildContext _) => const Align(
                    alignment: Alignment.topCenter,
                    child: Text('arriba del todo'),
                  ),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final double top = tester.getTopLeft(find.text('arriba del todo')).dy;
    expect(
      top,
      greaterThanOrEqualTo(notch.top),
      reason: 'the top of a session sits below the status bar, not under it',
    );
  });
}
