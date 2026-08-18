# `2 › 4` is not a thing to print in a maths app

## Why

Reported from play: *"why 2 > 4?"*

The function machine and the analogy both drew `BrandGlyph.forward` between two numerals, and
that glyph's stand-in is **`›`**. Set between `2` and `4` it is indistinguishable from `>`, so
the screen reads as **`2 > 4`** — a false statement, printed by a maths app, on the one screen
where a player is being asked to work out a relationship from the numbers in front of them.

`forward` is the right glyph where it means *"this card opens something"* — the home's puzzle
list. Reusing it as an arrow is what put a comparison operator between two numbers.

## What changes

- A separate `BrandGlyph.mapsTo`, drawn `→`, for "becomes".
- The function machine and the analogy use it; the home's card keeps its chevron.
- A gate: the mapping glyph must not render any character a reader would take as a relation
  between the numbers either side of it.

## Out of scope

The other stand-in glyphs. They are placeholders until the design digests arrive, and none of
the rest sits between two numerals.
