# Design — the first run

## D1 · Onboarding ships twice, and that is the decision rather than a compromise

The drawn path is `0.2 → 0.3 → 0.4 → 0.5 ×10 → 0.6 → mapa`. Calibration is F4 and the map is F5, so
F2 can ship only the first two screens.

The alternative was to ship `0.4` too and let it promise *"unos rápidos para acomodar tu nivel"* —
a promise the F2 build cannot keep, because nothing in it adapts to a level. **Two small builds beat
one broken promise** (D11), and the second build is a branch added to a path that already exists
rather than a rewrite.

## D2 · The completion flag is a flag, not a version

One boolean under one key. The temptation is to store a version number so a later onboarding can be
re-shown to existing players; the reason not to is that nobody has asked for that, and a version
whose semantics nobody has decided is a decision taken by default. A key rename does the same job on
the day it is actually wanted.

## D3 · Unreadable storage shows the onboarding

If the flag cannot be read, the app shows the welcome screen. The alternative — assume completed —
skips the only screen that teaches the answer format, for a player who may never have seen it.
Showing it twice costs a few seconds; skipping it costs the explanation.

Same shape as the day log's rule and for the same reason: **storage is the one input nobody reviews.**

## D4 · The teaching item is fixed and unrated

`0.3` teaches how an answer is typed. It is not a measurement, so it is drawn from no pack, feeds no
rating, and does **not** record a day for the streak — a streak that started before the player
reached the home would be counting the tutorial.

## D5 · Aki is absent from `0.3` and present on `0.2`

`0.2` is a greeting and she belongs there. `0.3` is solving, and the rule is that Aki never appears
while the learner is solving — the same rule the item screen already keeps. The digest has this
right and the design note records it as deliberate.

## Alternatives rejected

- **Shipping `0.4` with the calibration promise.** D1.
- **A version number instead of a flag.** D2.
- **Assuming completion when storage fails.** D3.
- **Fetching `0.3`'s item from the pack.** It would make the tutorial depend on content and vary
  between installs, and it would tempt someone to rate it.
