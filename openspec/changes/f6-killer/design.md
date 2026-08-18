## Context

See `proposal.md`. The board, the reader, the entry policy and the screen all exist and were built
for four formats. This is the first test of that claim.

## Goals / Non-Goals

**Goals:** Killer playable; the cage label honest about what the format carries; no dead keys.

**Non-Goals:** Magic Square, Kakuro, Word Search. No change to any frozen format.

## Decisions

### D1 · `operation` becomes optional rather than Killer getting its own cage type

A Killer cage is a KenKen cage with one field missing. Two cage types would mean two cage renderers,
two outline computations and two label rules, to model an absence.

The reader is where the difference is enforced: KenKen's requires an operation and Killer's refuses
one. So the model is permissive and the parsers are strict, which is the right way round — the model
describes what can be drawn, and the frozen schemas say what may arrive.

### D2 · A single-cell cage never shows an operation, whatever the format

Already true for KenKen and now stated once rather than twice. `3+` on one cell is not a sum.

### D3 · The pad dims rather than shrinks

`KeypadLayout.puzzle` is frozen at 5×2. Removing keys would change the layout, move every remaining
key and make a 3×3's pad a different shape from a 6×6's — so the keys stay where they are and the
ones that cannot act say so. The rule that refuses them is unchanged; only the presentation is new.

## Risks / Trade-offs

- **Making `operation` optional could let a KenKen cage lose one silently** → the KenKen reader
  requires it and a test feeds a KenKen cage with none.
- **Dimming touches the shared `Keypad`** → the round uses the same widget, so the disabled set is a
  parameter that defaults to empty and the round passes nothing.
