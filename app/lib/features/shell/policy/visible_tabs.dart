/// Which navigation tabs the shell draws.
///
/// **A rendering rule, not a scope decision** (D12). Four tabs are drawn in the
/// design; at F2 exactly one has a root. A four-tab bar with three dead tabs is
/// worse than no bar, and the missing roots are a build-order fact rather than
/// features anyone cut — the skill map arrives at F5 and the profile at F7.
///
/// Pure: a set in, an ordered list out.
library;

/// The tabs the design draws, in the order it draws them.
enum AppTab { home, skills, progress, profile }

/// The tab roots that exist in the app today.
///
/// **Three, since `Avance` landed** — and that is the whole mechanism by which
/// the bar grows. Nothing in `visibleTabs` changed either time; a destination
/// was added and the rule below started returning one more. This constant is
/// the single place the fact lives, exactly as it was kept for.
///
/// `skills` arrives at F5. Three live tabs is an honest bar; four with one dead
/// is the thing this file argues against.
const Set<AppTab> rootsPresentToday = <AppTab>{
  AppTab.home,
  AppTab.progress,
  AppTab.profile,
};

/// The tabs to render, given which ones have roots.
///
/// Returns **nothing** for a single root: a bar with one tab has nothing to
/// switch to, and drawing one would imply the other three are coming back from
/// somewhere the player could reach.
List<AppTab> visibleTabs(Set<AppTab> withRoots) {
  if (withRoots.length < 2) {
    return const <AppTab>[];
  }
  // Declaration order, not insertion order: a tab that moves depending on which
  // root registered first is a bar that shifts under the player.
  return AppTab.values.where(withRoots.contains).toList();
}
