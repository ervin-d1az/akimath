# Tasks

## 1. The shared pieces

- [x] 1.1 `design/widgets/detail_header.dart` — back control plus a
  fit-to-width Darumadrop title. Test that a long title shrinks and a short one
  does not, and that the back control clears 48.
- [x] 1.2 `design/widgets/settings_row.dart` — `height:62`, radius 20,
  `shadowTile`, label, optional trailing widget, optional chevron. Test all
  three trailing shapes.

## 2. The profile root

- [x] 2.1 `features/profile/ui/profile_screen.dart` — the identity row (avatar
  tile with Aki clipped, the address, the gear), the account state and the
  erasure door. Test that it prints no rating and no history.
- [x] 2.2 `features/profile/ui/profile_route.dart` — the state that owns the
  push, moved from `preferences_route.dart` rather than rewritten.

## 3. The stack

- [x] 3.1 `PreferencesScreen` becomes the settings list: a `DetailHeader` and
  the rows that lead somewhere. Test the row count is reported and non-zero,
  and that the three undesigned rows are absent.
- [x] 3.2 The account detail — what `Cuenta` opens.
- [x] 3.3 The legend detail — what `Cómo se leen los retos` opens.

## 4. The bar

- [x] 4.1 `NavBar.labelOf(AppTab.profile)` reads `Perfil`, and the glyph is the
  profile mark. Test that no tab is named after a settings screen.
- [x] 4.2 `shell_tour_test.dart` walks to the profile, opens the stack, and
  comes back — with the bar still drawn at every step.

## 5. Evidence

- [x] 5.1 Tier 1 — analyze, tests, metrics, with the counts stated.
- [x] 5.2 Tier 1b — 10 falsifications, 10 killed: the header ceasing to fit,
  a chevron on a row that opens nothing, the value moving past the chevron,
  an undesigned row appearing, `rowCount` drifting from the list, the tab
  called Ajustes again, two tabs sharing a mark, the tab losing its own
  navigator, a system back never reaching it, and the state view drawing
  the address a second time.
- [x] 5.3 Tier 2 — the tab, the push and the pop on the simulator.

---

## Found on the device, not in the suite

Two defects, both caught by running the tour on a phone rather than by reading:

- **The push took the bar with it.** The settings list went onto the app's root
  navigator, which covers the whole `Scaffold`. `TabStack` gives every tab its
  own navigator so a pushed screen lands **under** the bar, which is what the
  group badge over `4.1`–`4.7` says, and `RootScaffold`'s `PopScope` lets a
  system back pop the tab before it leaves the app — without it the first press
  discards a stack the player can see, which reads as a crash.
- **A long address overflowed at 1.3.** The design's value-bearing row was drawn
  for `19:30`; an email is four times that. The address is a card with the label
  above the value now.

One more the unit suite did catch first: the address rendered **twice** on the
profile, because the identity row and the state view both drew it. The identity
row owns it; the state view owns the state.
