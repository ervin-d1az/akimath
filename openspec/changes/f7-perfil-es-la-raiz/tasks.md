# Tasks

## 1. The shared pieces

- [ ] 1.1 `design/widgets/detail_header.dart` — back control plus a
  fit-to-width Darumadrop title. Test that a long title shrinks and a short one
  does not, and that the back control clears 48.
- [ ] 1.2 `design/widgets/settings_row.dart` — `height:62`, radius 20,
  `shadowTile`, label, optional trailing widget, optional chevron. Test all
  three trailing shapes.

## 2. The profile root

- [ ] 2.1 `features/profile/ui/profile_screen.dart` — the identity row (avatar
  tile with Aki clipped, the address, the gear), the account state and the
  erasure door. Test that it prints no rating and no history.
- [ ] 2.2 `features/profile/ui/profile_route.dart` — the state that owns the
  push, moved from `preferences_route.dart` rather than rewritten.

## 3. The stack

- [ ] 3.1 `PreferencesScreen` becomes the settings list: a `DetailHeader` and
  the rows that lead somewhere. Test the row count is reported and non-zero,
  and that the three undesigned rows are absent.
- [ ] 3.2 The account detail — what `Cuenta` opens.
- [ ] 3.3 The legend detail — what `Cómo se leen los retos` opens.

## 4. The bar

- [ ] 4.1 `NavBar.labelOf(AppTab.profile)` reads `Perfil`, and the glyph is the
  profile mark. Test that no tab is named after a settings screen.
- [ ] 4.2 `shell_tour_test.dart` walks to the profile, opens the stack, and
  comes back — with the bar still drawn at every step.

## 5. Evidence

- [ ] 5.1 Tier 1 — analyze, tests, metrics, with the counts stated.
- [ ] 5.2 Tier 1b — falsification over the row list and the header's fit.
- [ ] 5.3 Tier 2 — the tab, the push and the pop on the simulator.
