## Context

See `proposal.md` — Why. Almost everything is already built and tested; this change is mostly
wiring, and the design notes exist only where a real choice was made.

## Decisions

### D1 · Five, and the number lives in the policy

`ARCHITECTURE.md` §9 says five. It goes in `series_plan.dart` as a named constant beside the function
that uses it, not in a widget, so the screen has no opinion about how long a series is and the number
has one home.

### D2 · The plan is deterministic, and says so out loud

Which five items a player gets is `f4-calibration`'s question, and it is a real one — adaptive choice
is the product's premise. Until then a shuffle would be a *worse* answer than an obvious order,
because it invents variety the system cannot yet justify and makes a bug unreproducible. Taking the
first five in pack order is boring, reproducible, and honestly temporary.

*Alternative.* Seeded shuffle from the pack id — rejected: it looks adaptive, is not, and gives
`f4-calibration` a behaviour to preserve that nobody chose.

### D3 · A pack shorter than a series yields a shorter series

Padding by repeating an item would show a player something they answered ninety seconds ago and call
it a challenge. The shipped pack has twenty, so this is defensive — but the alternative fails
silently and this one is one `min`.

### D4 · The summary is a screen, not a dialog, and it is the round's

It lives in `features/round/ui/summary/` beside `verdict/`, because a series is the round's unit.
It takes its numbers and renders them; the counting happens in `RoundScreen`, which already tracks
the verdicts it produced.

### D5 · No rating, and no placeholder for one

The design draws three tiles and two meters on `2.5`, and two of those figures are the server's.
Q3/D17 already took the rating off both verdict screens for exactly this reason, and a greyed-out
pill would be the thing that decision rejected — a figure a later sync could contradict. The summary
ships the three F2 can source: right out of five, elapsed, streak.

## Risks / Trade-offs

- **Five feels short** → it is what §9 fixed as the first-playable target, and the number is one
  constant in one pure module when that changes.
- **The same five every time** → deliberate and temporary (D2), and the pack has twenty, so a second
  series drawing the same five is visibly wrong rather than subtly wrong. `f4-calibration` is where
  it stops being a placeholder.

## Open Questions

1. **What a second series in one sitting should draw.** Today it would draw the same five. Whether
   that advances through the pack, reshuffles, or is simply not offered is a product decision, and it
   is the first thing a player will notice.
