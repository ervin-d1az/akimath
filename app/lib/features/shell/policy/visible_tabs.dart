/// Which navigation tabs the shell draws.
///
/// **A rendering rule, not a scope decision** (D12). Four tabs are drawn in the
/// design and three of them have a root today. A bar with a dead tab on it is
/// worse than a bar one short, and the missing root is a build-order fact
/// rather than a feature anyone cut — nobody has drawn `Avance`.
///
/// Pure: a set in, an ordered list out.
library;

/// The tabs the design draws, in the order it draws them.
enum AppTab { home, skills, progress, profile }

/// The tab roots that exist in the app today.
///
/// **Three, since the map got a door.** `05 MAPA` and `2.7 Detalle de nodo`
/// landed fully tested with no tab that opened either, which is the one way a
/// screen can be finished and still not exist for a player. `Avance` went the
/// other way earlier: no document in the design draws a progress screen, and
/// every figure ours showed is a figure `4.1 Perfil` puts under the identity,
/// so the profile absorbed it.
///
/// **`AppTab.progress` stays in the enum on purpose.** Declared rule 1 names
/// the bar's homes as *inicio, mapa, progreso y perfil*, so a progress root is
/// something the design asks for and nobody has drawn — which is a different
/// fact from it not existing. This constant is the list of what has a
/// destination, and it is the one that moves.
///
/// That is the whole mechanism by which the bar changes size. Nothing in
/// `visibleTabs` has changed on any of the four occasions — none, two, three,
/// two, three: a destination was added to or removed from this set and the
/// rule below returned one more or one fewer.
const Set<AppTab> rootsPresentToday = <AppTab>{
  AppTab.home,
  AppTab.skills,
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
