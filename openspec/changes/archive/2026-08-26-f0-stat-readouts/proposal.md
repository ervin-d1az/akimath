## Why

`StatTile`, `StatPill`, `BaselineMeter` and `OutlinedChip` appeared in the first draft's component
inventory and in **no change at all**. All four are on F2 screens: `03 Acierto` draws stat tiles and
a meter with a baseline marker, `04 Error` draws flat tiles and an inline h14 meter, `2.5` draws
tiles and two meters, and the counter chip (`5 retos`, `3 / 9`) is `OutlinedChip`.

The round today shows a verdict ring and nothing else. Everything the player learns from an
answer — how long it took, how the series is going, where they are on a skill — needs these.

**Phase: F0.** It blocks `f2-core-loop`'s verdict screens, `f2-home-reduced` and `f2-series-summary`.

## What Changes

- **`BaselineMeter`** — a progress track with a baseline marker, whose fill is typed as a
  `MasteryLevel` and **never as a `Color`**.
- **`MeterLayout`** — the marker geometry as pure data.
- **`StatTile`** in three variants: `raised`, `compact`, `flat`.
- **`StatPill`** in two sizes: `header` and `hero` (K8, decided 2026-08-15).
- **`OutlinedChip`** — the counter chip.
- **`app/test/architecture/no_hue_by_comparison_test.dart`** — a new gate: no widget picks a colour
  by a numeric comparison.

## Capabilities

### New Capabilities
- `stat-readouts`: how the app prints a measured number, and how it shows progress without letting a
  widget decide a hue.

## Impact

- **New:** `design/widgets/{baseline_meter,stat_tile,stat_pill,outlined_chip}.dart`,
  `design/widgets/spec/{meter_layout,mastery_level}.dart`.
- **New gate:** `no_hue_by_comparison_test.dart`, which constrains every future widget, not just
  these.
- Covered by the existing `design/**/spec/` pure root and both literal gates.
- **No new dependency.**

## Non-goals

- **How many tiles a screen mounts.** This change ships **variants, not instances**. `03` and `04`
  draw three tiles in the documents and ship **two** — Q3 and Q4, decided 2026-08-15, took the
  rating-delta tile off both. That is `f2-core-loop`'s decision, and the distinction is worth stating
  because "draws three" one phase from "ships two" is exactly how a third tile gets written.
- **The rating.** It is the server's exclusive authority (D17) and no server exists. `StatTile`
  renders a delta it is handed.
- **Motion.** A meter that fills over time is F8.

## What this builds on

- **`PressableSurface`** — landed in `f0-pressable-surface`; the pressable readouts inherit it.
- **`EsMxNumber.deltaParts`** — landed in `f1b-math-compositor`. The delta's sign and digits are two
  runs precisely so a tile never composes a minus by hand.
- **`Verdict`** — the precedent for typing a state without a colour on it.
