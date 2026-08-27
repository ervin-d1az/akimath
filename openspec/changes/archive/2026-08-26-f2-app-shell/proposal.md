## Why

Every screen so far is its own `Scaffold` painting its own cream. There is no frame, no place for a
banner, and no rule about navigation — so the first time a second root exists, four screens will each
have their own opinion about whether a bar belongs.

**Phase: F2.** It blocks every F2 screen.

## What Changes

- **`features/shell/policy/visible_tabs.dart`** — the rule that decides whether a bar is drawn at
  all. Pure.
- **`features/shell/policy/banner_visual.dart`** — the banner variant map. Pure, and it always
  returns a glyph.
- **`features/shell/ui/app_shell.dart`** — the cream frame, the banner slot, and
  `fullScreenSession`, which pushes a route with no navigation affordance.
- **`features/shell/ui/inline_banner.dart`** — one banner, two placements.
- **`features/shell/ui/skeleton_block.dart`** — content-shaped placeholders.
- **`main.dart`** routes through the shell.

## Capabilities

### New Capabilities
- `app-shell`: the frame, the navigation-staging rule, the banner and the loading placeholders.

## Impact

- **New:** two pure modules under `features/shell/policy/`, three widgets under
  `features/shell/ui/`.
- `features/*/policy/` under the pure root goes from 3 files to 5.
- **No new dependency.**

## Non-goals

- **A bottom navigation bar.** `AppBottomNav` needs a second root and the map is F5 (D12). The rule
  that would draw it exists and is consumed; the bar does not.
- **The home screen.** `f2-home-reduced`. The round is the single root today.
- **The three undrawn offline states** — DR-1 to DR-3. The banner exists; what it says in each of
  those states is a design request.
- **Motion.** A shimmering skeleton is motion, and motion is F8.

## What this builds on

`CandySurface` for the banner, `BrandIcon` for its glyph, and the tokens for everything else.
