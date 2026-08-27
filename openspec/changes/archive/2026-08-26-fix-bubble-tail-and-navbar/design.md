# Design

## D1 — Do not draw the line you then have to hide

The old tail stroked a closed triangle — including its top edge, across the mouth — and then
painted a white patch over that edge *and* the bubble's border. Two things to cover, one patch,
and it was short.

Stroking only the two slanted sides removes half the problem outright. What remains is the
bubble's own border, which the patch handles, and the patch can then be sized for one line
rather than two overlapping ones.

## D2 — The box is 18 tall because the coordinates are

`M3 2 L23 2 L11 16 Z` is written for a `26×18` viewBox. The widget declared the box 16 tall, so
every y was scaled by 8/9 — including the patch, which is why a `h=4` patch could not clear a
3 px border. Making the box 18 makes the numbers in the path mean what the design says they
mean, and the extra two units at the bottom are the overshoot the apex needs.

## D3 — The patch is measured, not transcribed

The design's `rect x=5 y=-2 w=16 h=4` covers 2 units above the mouth. A 3 px border needs 3, and
the stroke has a half-width beyond that. So the patch reaches `-stroke - 1` rather than `-2`:
the design's intent is *"remove the seam"*, and a transcription that leaves a hairline has
copied the number and missed the instruction.

## D4 — The nav bar is the same object as everything else

Every other surface in this app is a bordered card with a hard shadow. The bar was the single
exception — a full-bleed strip with a hairline on top — and `BrandShape.shadowButton`'s own doc
comment already listed "the bottom nav" among what it is for. The token was waiting.

## D5 — A chip instead of a dot

The dot was invented because the icons were not ready and the bar needed *some* shape
difference for BRD-1. The design's answer is a chip, which is a shape the rest of the app
already speaks, and it satisfies the same invariant without inventing a mark. The labels stay
until the icon artwork lands, for the reason the old comment gave: a wrong glyph reads worse
than a word.
