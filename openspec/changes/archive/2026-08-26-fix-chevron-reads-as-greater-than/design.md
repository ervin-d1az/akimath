# Design

## D1 — Two meanings needed two names

`BrandGlyph.forward` was carrying both *"this card opens something"* and *"this input becomes
that output"*. Those are the same arrow in a designer's head and different characters on a
screen: the first is a chevron, the second is an arrow, and only the second is ever set between
two numbers.

One name for both meant the stand-in chosen for one was inherited by the other. Splitting them
is what makes the stand-in choice reviewable per meaning — and when the design digests arrive,
each gets its own transcribed mark instead of one being wrong twice.

## D2 — The gate names the characters rather than the glyph

The test forbids `›`, `‹`, `>`, `<`, `=`, `≥` and `≤` as the *rendered face* of `mapsTo`, not
merely "not `BrandGlyph.forward`". A future stand-in picked carelessly — `»`, say, or `≫` — would
pass a test that only checked which enum member was used. What matters is what a player sees.

## D3 — The arrow renders, and that was checked rather than assumed

`BrandIcon` draws its stand-in in `BrandText.numeral`, which is Darumadrop One. A character the
font lacks would render as tofu, and a test that only asserts `find.text('→')` would pass on a
tofu box — `find.text` matches the string, not the glyph the font produced.

So it was rendered on the simulator: `2 → 4`, `7 → 9`, `10 → ?` all draw the arrow. That is the
part a widget test structurally cannot answer.
