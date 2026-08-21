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
/// Every tab has one, including the tab that pushes nothing today. A wrapper
/// applied only where it is currently needed is one the next root will be
/// missing.
///
/// **The root is a `Page`, and that is the fix for a real defect.** It used to
/// be an `onGenerateRoute` whose `pageBuilder` closed over the child handed in
/// at the first build. `onGenerateRoute` runs once, so every later rebuild of
/// the shell produced a root widget that was never mounted — the shell could
/// not hand a tab anything after the first frame. The session `RootScaffold`
/// holds travels that way, so **signing in changed nothing on screen**: no
/// address, no link, no history, and a home that never learned it could sync.
/// The declarative form updates the route's settings in place instead, and
/// [_RootRoute] reads the child out of them rather than out of a closure.
class TabStack extends StatelessWidget {
  const TabStack({super.key, required this.child, this.navigatorKey});

  /// The tab's root screen.
  final Widget child;

  /// Held by the shell, so a system back can reach this stack before the app
  /// decides to close.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// The root page's identity, and it is **stable on purpose**.
  ///
  /// The Navigator matches old pages to new ones by key. A fresh key each build
  /// would tear the root's element tree down and build another, which is
  /// exactly what the shell's `IndexedStack` exists to prevent — the home would
  /// re-read its pack and flash a skeleton on every tab switch.
  static const ValueKey<String> _rootKey = ValueKey<String>('tab-root');

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
      pages: <Page<void>>[_RootPage(key: _rootKey, child: child)],
      // Nothing removes the root, and anything pushed above it is imperative —
      // `Navigator.pop` handles its own removal. This callback exists because
      // a `pages` Navigator must declare one.
      onDidRemovePage: (Page<Object?> removed) {},
    );
  }
}

/// The tab's root as a page, so the Navigator can update it rather than
/// replace it.
class _RootPage extends Page<void> {
  const _RootPage({required LocalKey super.key, required this.child});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => _RootRoute(this);
}

class _RootRoute extends PageRoute<void> {
  _RootRoute(_RootPage page) : super(settings: page);

  /// **Read from `settings`, never from a field of this route.** The Navigator
  /// hands the new page in by replacing the settings and then asks the route to
  /// build its content again; a route holding the child it was constructed with
  /// would hand back the same stale widget for ever, which is the defect this
  /// class exists to end.
  Widget get _child => (settings as _RootPage).child;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      _child;

  /// **No transition for the root.** It is not arriving from anywhere — it is
  /// the tab — and animating it would make every tab switch a slide over the
  /// one before it.
  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;
}
