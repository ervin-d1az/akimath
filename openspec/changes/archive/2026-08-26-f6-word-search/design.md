## Context

See `proposal.md`. Four formats share a board; this one shares only the pack envelope, the header
and the full-screen session.

## Decisions

### D1 · A screen of its own

`PuzzleScreen` composes a board and a keypad, and a word search has neither. Bending it to draw a
letter grid with no pad would make every future change to either format a change to one widget, and
the shared parts — the header, the rules toggle, the way out — are small enough to extract.

### D2 · The search is pure and shared between the reader and the player

The reader asks "is this word anywhere in this grid"; a claim asks "do these cells spell a word".
Both are the same eight-direction reading, so one module answers both. A second implementation would
be free to disagree about diagonals, and a player would experience that disagreement as a correct
answer refused.

### D3 · Eight directions, because the frozen validator uses eight

A reader searching only the four an author happened to use would accept a pack whose words the
player cannot claim.

### D4 · A found word is struck through, not dimmed

BRD-1. Dimming is a hue difference; a line through the word survives with the hue gone.

## Risks / Trade-offs

- **An 8×8 grid at textScaler 1.3 is tight** → registered at the largest size the format admits and
  measured by the overflow gate.
- **Drag selection is fiddly to test** → a claim is a pure function of a cell list, so the policy is
  tested without gestures and the widget only has to produce that list.
