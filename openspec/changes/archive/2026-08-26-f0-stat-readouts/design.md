# Design — the stat readouts

## D1 · The meter takes a level, not a colour

`BaselineMeter(fill: MasteryLevel)` rather than `BaselineMeter(color: Color)`. Same construction as
`Verdict`: with no colour parameter, "decide the meaning at the call site by picking a hue" is not
something a caller can express.

The failure this prevents is specific and common — `pct >= 90 ? green : pink` written inline in a
widget. That scatters the mastery thresholds across every screen that draws a bar, so changing what
"mastered" means becomes a search rather than an edit.

## D2 · The gate is worth more than the widget

`no_hue_by_comparison_test.dart` scans for a colour selected by a numeric comparison. It constrains
**every future widget**, not the four in this change, and it is the reason to write the rule as a
scan rather than as a convention.

Its limits, stated so they are read as limits rather than found as bugs: a text scan cannot see a
comparison assembled across two statements, and it necessarily allows a colour chosen by a
comparison on an *enum*, which is what `MasteryLevel` resolution legitimately is. It raises the
floor; it does not replace the reviewer.

## D3 · Variants, not instances

This change fixes the three `StatTile` variants and the two `StatPill` sizes. **How many tiles a
screen mounts is that screen's decision.**

The documents draw three tiles on `03` and `04`; Q3 and Q4 took the rating-delta tile off both, so
F2 ships two. Both facts are true and they belong to different changes. §4 is where an implementer
builds from, and "draws three" one phase away from "ships two" is exactly how a third tile gets
written by someone reading the wrong sentence.

## D4 · `StatPill` has two sizes because comparing to the default hid the truth twice

The first draft collapsed `0.6`'s rating chip into the header size — h64 / r22 / shadow (4,6) with a
Darumadrop 38 value, forced through h48 / r24 / shadow (3,5). That is the same failure the plan warns
about with `CandySurface.pill`: the wrong constructor lands the wrong radius and the wrong shadow.
The second draft removed `4.12`'s badge for the same reason and left **both** screens holding local
compositions.

K8 settles it by comparing the two screens **to each other** rather than each to the default: `0.6`
(h64 / r22 / shadow (4,6)) and `4.12` (h56 / r22 / shadow (4,6) on yellow) agree on radius and shadow
and differ only in height and fill — a size and a `background`, both of which the row already
carries.

What survives from the earlier reasoning is the method, not its conclusion. Three of four measures
really did disagree with `header`; comparing each screen to the default instead of to its sibling is
what hid the shared geometry for two drafts.

## D5 · The delta is two runs

A `−6` delta is a Plus Jakarta 800 sign beside Darumadrop digits, baseline-aligned. It is rendered
from `EsMxNumber.deltaParts`, which already returns the sign and the digits separately — precisely
so that no tile concatenates a minus by hand and lands a hyphen.

## Alternatives rejected

- **`BaselineMeter(color:)`.** D1.
- **A `mastered` boolean instead of a level.** The corpus draws more than two states, and a boolean
  forces the third into a second flag.
- **One `StatPill` size with per-call overrides for radius and shadow.** That is the
  `CandySurface.pill` failure again: a component whose geometry is overridden at the call site is
  not governing anything.
