## Why

The app opens straight into a round. There is nowhere to stand before starting one, nowhere for the
streak to live, and `fullScreenSession` — built with the shell — has no caller, so declared rule 1 is
enforced by a test and by nothing a player can reach.

**Phase: F2.** `Inicio actualizado` is the canonical home (D5); this ships a named subset of it.

## What Changes

- **`features/home/ui/home_screen.dart`** — the Aki band at 150 with the bubble, the
  `RETO DEL DÍA` card whose expression is **composed by the real compositor**, the streak pill, and
  one primary button.
- **`features/home/ui/home_route.dart`** — loads the pack, resolves the streak, and pushes the
  series as a full-screen session.
- **`main.dart`** opens on the home.
- **`StatPill` fixed**: it stretched to fill the width it was offered.

## Capabilities

### New Capabilities
- `home`: what the app offers before a series starts, and how a series is entered.

## Impact

- **New:** two files under `features/home/ui/`.
- **Modified:** `design/widgets/stat_pill.dart` — a real defect, found on the device.
- `screen_registry.dart` gains the home, **inside its shell**.
- **No new dependency.**

## Non-goals

Each with the phase it returns in, because none is a cut:

- **The rating pill — F3.** The rating is the server's exclusive authority and there is no server
  (Q3, D17).
- **The `PUZZLE DEL DÍA` card — F6.**
- **The bottom nav — F5**, when a second root exists.
- **The `TUS HABILIDADES` row — dropped, not deferred.** It is the structural difference between the
  two home documents, and choosing `Inicio actualizado` means losing it.
- **`DayLogStore`.** `attemptDays` is passed in; persistence is a later change, so the streak reads
  zero on a fresh launch today.

## What this builds on

`AppShell` for the frame and `fullScreenSession` for the series, `MathView` for the preview,
`StatPill` for the streak, `StreakPolicy` for its value, and `PackReader` for the item.
