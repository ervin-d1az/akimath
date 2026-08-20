import 'package:flutter/widgets.dart';

/// A tab's own navigation stack, drawn inside the shell rather than over it.
///
/// **The bar has to survive a push.** The settings screens sit above the
/// profile root, and the design says so where it groups them: *"Aquí sí va la
/// barra inferior."* A route pushed onto the app's root navigator covers the
/// whole `Scaffold`, bar included — which is what the app did, and what an
/// integration test on a device caught.
///
/// So each tab gets a `Navigator`. Its first route is the tab's root, and
/// anything the root pushes lands inside it, under the bar.
///
/// Every tab has one, including the two that push nothing today. A wrapper
/// applied only where it is currently needed is one the next root will be
/// missing.
class TabStack extends StatelessWidget {
  const TabStack({super.key, required this.child, this.navigatorKey});

  /// The tab's root screen.
  final Widget child;

  /// Held by the shell, so a system back can reach this stack before the app
  /// decides to close.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Pops [key]'s stack if it has anything to pop.
  ///
  /// Returns whether it handled the gesture. **The shell asks this before
  /// letting a back press leave the app**: without it the first press discards
  /// a stack the player can see, which reads as the app crashing rather than as
  /// navigation.
  static Future<bool> popTab(GlobalKey<NavigatorState> key) async {
    final NavigatorState? navigator = key.currentState;
    if (navigator == null || !navigator.canPop()) {
      return false;
    }
    return navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (RouteSettings settings) => PageRouteBuilder<void>(
        settings: settings,
        // **No transition for the root.** It is not arriving from anywhere —
        // it is the tab — and animating it would make every tab switch a slide
        // over the one before it.
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
        ) =>
            child,
      ),
    );
  }
}
