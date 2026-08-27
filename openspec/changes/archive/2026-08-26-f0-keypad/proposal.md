## Why

**The app cannot accept an answer.** Every screen that takes numeric input — the item screen, the
puzzle boards, the OTP field, calibration — is blocked on it, and `CLAUDE.md` forbids the system
keyboard outright for numeric entry.

**This change exists because the first draft did not have one.** D14 says the three layouts *share*
`KeypadKey`, and the draft then filed `ItemKeypad` under `round`, `PuzzleKeypad` under `puzzles` and
`OtpKeypad` under `auth` — three adapters, no shared key, no owner, no build slot. Written that way
the U+2212 / U+00B2 / U+002C codepoint contract (risk R2) is re-typed in three features.

**Phase: F0.** On the critical path: `f2-core-loop` has no answer path without it.

## What Changes

- **`app/lib/design/widgets/spec/keypad_layout.dart`** — the three layouts as pure data. Key ids,
  faces and per-key fills, in a module that touches no widget and no `Canvas`.
- **`app/lib/design/widgets/keypad.dart`** — one `KeypadKey` and one `Keypad` that render any
  layout. They hold **no answer rule**: the keypad reports what was pressed and never decides what
  it means.
- **The codepoint contract typed once**: the negate key emits U+2212, never U+002D; the square key
  U+00B2; the decimal key U+002C.

## Capabilities

### New Capabilities
- `keypad`: the three numeric layouts, the one key that renders them, and the codepoints they emit.

### Modified Capabilities

None.

## Impact

- **New:** `design/widgets/spec/keypad_layout.dart`, `design/widgets/keypad.dart`.
- **New tests:** `test/design/widgets/spec/keypad_layout_test.dart`, `test/design/widgets/keypad_test.dart`.
- **`design/widgets/spec/` is covered by the existing `design/**/spec/` pure root** — a glob, so
  nothing needs declaring.
- **No new dependency.**

## Non-goals

- **Deciding whether an answer is right.** The keypad emits key presses. Grading is elsewhere and
  the answer never travels (`ARCHITECTURE.md` §4).
- **A disabled-key visual.** None exists anywhere in the corpus — that is **DR-K1**, not a gap this
  change fills by invention. Same for the submit arrow on an empty answer (DR-K2) and illegal-digit
  feedback on a board with no submit key (DR-K4).
- **Unifying the two digit orders.** The item pad is calculator order (7-8-9 top) and the puzzle pad
  is reading order (1-2-3 top). The digest says so explicitly and says not to unify them without a
  design decision. One widget, two orders, as data.
- **The system keyboard.** Forbidden by `CLAUDE.md`, and asserted absent.

## What this builds on

- **`PressableSurface`** — landed in `f0-pressable-surface`. A key is that primitive with fixed
  geometry, so the press rule is inherited rather than restated.
- **`BrandIcon`** — landed alongside `f0-brand-icons`' allowlist. The backspace and submit faces go
  through the named seam, so transcribed path data later changes no call site here.
- **`FractionGlyph`** — the `a/b` key face. The plan assigned its `plain` variant to *this* change
  (§4.0 decision (a)); it landed early in `f1b-math-compositor` instead. The outcome is the same and
  the invariant that mattered still holds: **the plain variant takes a size and never a
  `FractionMetrics`.**
- **`BrandShape`** — border 3, radius 18, shadow (3,5), identical across all three documents.
