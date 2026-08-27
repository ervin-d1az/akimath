## Context

See `proposal.md` — Why. What shapes the approach:

- `visibleTabs(roots)` already returns two tabs the moment two roots exist, and `AppShell` already
  takes a `navBar` builder it has never been given. The bar is **enabled by adding a destination**,
  not by changing a rule.
- `screen_overflow_test.dart` holds every registered screen to 390×844 at textScaler 1.0 **and 1.3**.
  The home is gaining two bands; that gate is the binding constraint on this whole change.
- `nodeFor` throws for any non-arithmetic stimulus, and `HomeRoute` passes `pack.items.first`. The
  home is one pack reorder away from crashing on launch.
- BRD-1: success and error must differ by **shape**, not only hue. Anything this change draws in
  pairs — played/unplayed days, selected/unselected tabs, the verdict legend — inherits that.

## Goals / Non-Goals

**Goals:** a shell a player can move around in; a home that shows what the app is; screens that hold
at textScaler 1.3.

**Non-Goals:** the skill map (F5) and the progress tab — this change adds *one* root, not three.
Nothing from `4.1 Perfil` that needs a server. No new dependency.

## Decisions

### D1 · Preferences is the second root, and that is what turns the bar on

`rootsPresentToday` gains `AppTab.profile`. The policy is untouched, the shell is untouched in its
decision-making, and the bar appears. The alternative — shipping the bar with a disabled tab or a
placeholder screen — is the thing `visible_tabs.dart` already argues against: three dead tabs imply
the destinations are somewhere reachable.

`skills` and `progress` stay absent. Two live tabs is an honest bar; four with two dead is not.

### D2 · The home scrolls

Two new bands plus Aki, the card and the button do not fit 844 px at textScaler 1.3, and the fix is
not to shrink them until they do. A home that scrolls is ordinary; a home that clips at large text is
a bug for exactly the readers who chose large text.

This is not routing around the overflow gate. The gate asks that content is reachable and nothing
clips, and a scroll view satisfies it for the reason it exists rather than by suppressing it. The
band order is chosen so the CTA is above the fold at 1.0 — a player never has to scroll to start.

### D3 · The week strip is seven marks, always

Not "as many days as the streak". A strip whose length tracks the streak reflows the screen every
morning and cannot show a gap. Seven fixed marks ending on today show *which* days were played,
which is the fact a total cannot carry, and the number beside it carries streaks longer than a week.

Played and unplayed differ by fill **and** by outline, so the pair survives deuteranopia (BRD-1).

### D4 · The family row reads `seriesPlan`, not the pack

The row must say what the player is about to meet, so it is computed from the same plan that will
serve them. Describing the pack in general would be a different, and quietly wrong, statement — the
pack has six families and any given series has five.

### D5 · The preview stops throwing, by reusing the round's own dispatch

`HomeRoute` hands `pack.items.first` to a card that calls `nodeFor`, which throws on anything that is
not an expression. Rather than teach the home a second switch over `Stimulus`, the round's renderer
is extracted so both draw a stimulus the same way. Two dispatches over one sealed type is how the
home ends up drawing last month's idea of a matrix.

### D6 · Preferences ships one card, and the plan already decided which

`4.5` in the implementation plan: *"v1 ships one card: the `Acierto` / `Se torció` preview and its
legend"*, with `Reducir movimiento` deferred to F8 and text size, high contrast and colour-blind mode
undated or undefined. This change builds that card and adds the local facts a player has — days
played and the streak — and nothing else.

## Risks / Trade-offs

- **Two more bands could still overflow at 1.3** → the home scrolls (D2), and both new screens are
  registered so the gate measures them rather than being told they are fine.
- **A scrolling home could push the CTA out of sight** → band order puts it above the fold at 1.0,
  and the overflow gate measures the composed screen at both scales.
- **The family row is a second reader of `seriesPlan`** → it is the same call with the same
  arguments, and a test asserts the row and the served series agree rather than trusting that.
- **Enabling the bar changes every screen's bottom inset** → the registered screens are measured with
  the shell around them, which is how they are actually built.

## Migration Plan

None. No stored data changes shape; `DayLogStore`'s key and format are untouched. A player who
updates sees a splash, a fuller home and a second tab.
