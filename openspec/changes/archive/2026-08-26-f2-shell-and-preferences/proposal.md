## Why

The app has one screen a player can stand on. The splash is built in two approved
variants and **is not reachable from anywhere** — `main.dart` opens straight on
`FirstRunGate`, so a treatment that exists has never been seen. The bottom
navigation is absent by rule, correctly: `visibleTabs` returns nothing while one
root exists, and a bar with one tab has nothing to switch to. There is no
settings surface at all.

The home is the screen the product is judged by and it is mostly empty cream. It
shows a bare `7` with no label, and nothing that conveys the thing that actually
distinguishes this app — six kinds of question, not one.

## What Changes

- **A preferences root**, which is the second root the shell has been waiting
  for. The bottom navigation then appears **by rule** — `visibleTabs` already
  returns two tabs the moment two roots exist, so the bar is enabled by adding a
  destination rather than by changing the policy.
- **The bar itself**, which the shell has always accepted as `navBar` and never
  been given.
- **The splash is wired into startup**, brand green, shown while the pack and
  the stored preferences load.
- **The home gains a week strip and a family row.** A labelled streak with seven
  day-dots, and the families today's series will actually draw. Both are local
  facts — `StreakPolicy` over `DayLogStore`, and `seriesPlan` over the bundled
  pack — so neither waits on a server.
- **Preferences ships the one card `4.5` decides**: the `Acierto` / `Se torció`
  preview and its legend. The three toggles stay deferred with the reasons the
  plan already records (DR-P2).
- **NOT in this change**: rating, accuracy, mean time and the history feed. Those
  are `4.1 Perfil`'s and they are server data at F3. A settings screen that
  printed them would be printing figures nothing can compute.

## Capabilities

### New Capabilities

- `preferences`: what a player can see and set about their own use of the app
  without an account, and what settings may not claim.
- `app-navigation`: how a player moves between roots, and when a bottom bar
  exists at all.

### Modified Capabilities

- `home`: the home gains the week strip and the family row.
- `app-shell`: the shell gains a rendered bar and a startup splash.

## Impact

- `app/lib/features/preferences/` (new), `app/lib/features/shell/ui/` (the bar),
  `app/lib/features/home/ui/` (the two new bands), `app/lib/main.dart` (startup).
- `rootsPresentToday` gains `AppTab.profile` — the single place the plan says
  the "no bar yet" fact lives.
- No new dependency. No change to the pack format, the schema or any invariant.
