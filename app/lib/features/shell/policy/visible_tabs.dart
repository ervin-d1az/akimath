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
/// **Two, and it went down rather than up.** `Avance` was a root for a while
/// and is not one now: no document in the design draws a progress screen, and
/// every figure ours showed is a figure `4.1 Perfil` puts under the identity.
/// Splitting them left two half-empty screens where the design has one full
/// one, so the profile absorbed it.
///
/// **`AppTab.progress` stays in the enum on purpose.** Declared rule 1 names
/// the bar's homes as *inicio, mapa, progreso y perfil*, so a progress root is
/// something the design asks for and nobody has drawn — which is a different
/// fact from it not existing. This constant is the list of what has a
/// destination, and it is the one that moves.
///
/// That is the whole mechanism by which the bar changes size. Nothing in
/// `visibleTabs` has changed on any of the three occasions: a destination was
/// added or removed and the rule below returned one more or one fewer.
///
/// `skills` arrives at F5 and needs no edit here beyond its own name.
const Set<AppTab> rootsPresentToday = <AppTab>{
  AppTab.home,
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
