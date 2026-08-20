import 'package:flutter/material.dart';

import '../../../design/tokens/tokens.dart';
import '../policy/visible_tabs.dart';

/// The frame every screen sits in.
///
/// Cream, and **no bottom navigation** — `visibleTabs` returns nothing while
/// one root exists, so the bar is absent by rule rather than by omission (D12).
/// When the skill map lands at F5 the same rule draws it, with no change here.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    this.banner,
    this.roots = rootsPresentToday,
    this.navBar,
  });

  final Widget child;

  /// An optional banner across the top.
  final Widget? banner;

  /// Which tab roots exist. Defaults to what the app actually has.
  final Set<AppTab> roots;

  /// Builds the bar, given the tabs to draw.
  ///
  /// Injected because **no bar exists yet**: `AppBottomNav` arrives with the
  /// second root at F5. Passing it in rather than importing it keeps the
  /// staging rule consumed here today — the shell asks `visibleTabs` and gets an
  /// empty list, so it builds nothing — instead of leaving the policy without a
  /// caller until F5 and the rule enforced only by a test of itself.
  final Widget Function(List<AppTab> tabs)? navBar;

  /// The bar, or nothing.
  Widget? _bar() {
    final List<AppTab> tabs = visibleTabs(roots);
    return tabs.isEmpty ? null : navBar?.call(tabs);
  }

  @override
  Widget build(BuildContext context) {
    final Widget? band = banner;

    return Scaffold(
      backgroundColor: BrandColors.cream,
      // Absent, not hidden. `visibleTabs` returns an empty list while one root
      // exists, so there is nothing to build — a bar with one tab has nothing
      // to switch to.
      bottomNavigationBar: _bar(),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (band != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BrandShape.space4,
                  BrandShape.space2,
                  BrandShape.space4,
                  0,
                ),
                child: band,
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Pushes a screen as a **full-screen session**.
///
/// Declared rule 1: an item, a verdict, calibration and a puzzle take the whole
/// screen with no navigation affordance, and the only way out is the screen's
/// own close control. Routing it rather than swapping a tab body is what makes
/// that true structurally instead of by each screen remembering to hide things.
///
/// **Push it with [pushSession].** A session pushed onto a tab's own navigator
/// sits *under* the bottom bar: a player mid-item can tap away, and the screen
/// is laid out for 106 pixels it does not have. That is not hypothetical — it
/// is what happened the day each tab got its own stack, and a device found it
/// as a 24-pixel overflow.
Route<T> fullScreenSession<T>(WidgetBuilder builder) {
  return MaterialPageRoute<T>(
    fullscreenDialog: true,
    builder: (BuildContext context) => Scaffold(
      backgroundColor: BrandColors.cream,
      // **The route insets, not each screen.** Six screens went through here
      // and all six carried their own `SafeArea`; the seventh did not, and its
      // Aki sat under the Dynamic Island on a real phone. Six remembering and
      // one forgetting is the definition of a rule that belongs in one place,
      // which is the same argument this function was extracted for. The six
      // inner ones are now no-ops — a nested `SafeArea` sees no padding left to
      // consume — and they stay, because each is inside a `Scaffold` its screen
      // owns and the design registry pumps some of them directly.
      body: SafeArea(child: Builder(builder: builder)),
    ),
  );
}

/// Opens a session over everything, including the bar.
///
/// **`rootNavigator: true`, and that is the whole point of the function.**
/// `Navigator.of(context)` finds the nearest one, which since `TabStack` is the
/// tab's — so a plain push leaves the bar drawn under a round. Declared rule 1
/// says the opposite, and the difference is not cosmetic: the bar is a way out
/// of a session that is supposed to have exactly one.
///
/// Every caller that opens a round, a board or a streak notice goes through
/// here, so the choice is made once rather than remembered at each site.
Future<T?> pushSession<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(context, rootNavigator: true).push(fullScreenSession<T>(builder));
