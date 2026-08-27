# A selected cell you can actually see

## Why

Reported from play: *"when you select a cell is not clear."*

It is worse than unclear. Selection was drawn as a ring in `BrandColors.ink` at
`BrandShape.borderWidth` — **the cage outline's own colour and width, on the same edges**. A
cell whose cage encloses it on all four sides therefore showed *no selection at all*: the ring
landed exactly on a line that was already there.

On the shipped 4×4 KenKen that is most cells. A player taps, nothing changes, and the next digit
they press appears somewhere they were not looking.

The comment above it read *"Selection is a ring, not a wash. A tinted fill would be a hue
difference and nothing else"* — a reading of BRD-1 that treats hue as forbidden rather than as
insufficient. The invariant asks that a state survive **without** hue, not that it be carried
without hue.

## What changes

- **A selected cell is filled**, in the yellow that already means *"this is the thing you are
  working on"* — the hole in a stimulus and the letters under a finger in a sopa de letras use
  it, so this is a third instance of one idea rather than a new one.
- **The ring stays, inset**, so shape still carries the state for a reader who cannot separate
  the hues, and so it can never merge with the cage outline again.
- The fill is decided in the pure spec, not in the widget.

## Out of scope

The word search's own highlight, which already uses this yellow and was never the complaint.
