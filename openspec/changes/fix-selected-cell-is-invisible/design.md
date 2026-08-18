# Design

## D1 — BRD-1 asks that hue be unnecessary, not that it be unused

The comment this change deletes read: *"A tinted fill would be a hue difference and nothing
else."* That is true of a fill **alone**. It is not an argument against a fill *plus* a ring,
which is what the invariant actually wants — a state a deuteranopic reader can still find, and a
state everyone else can find instantly.

Reading the invariant as "no hue" produced a selection that satisfied it on paper and was
invisible in practice, which is the worse failure of the two.

## D2 — The yellow is already spelled twice

`term_visual.dart` uses `BrandColors.yellow` for the hole in a stimulus; `word_search_screen.dart`
uses it for the letters under a finger. Both mean *"this is the thing you are working on"*. A
board cell being worked on is the same idea, so it takes the same colour rather than a fourth
one to keep in step.

## D3 — The fill is the spec's decision, the ring is the widget's

`resolvePuzzleCell` already decides a cell's fill from what it is. Selection is one more input to
that question, so it goes there and stays testable without pumping a widget. The ring is
geometry on a `Stack` and stays where geometry lives.

## D4 — Inset by the border width

Flush, the ring is the cage outline. Inset by `BrandShape.borderWidth` it is a second line with
a visible gap, which is what makes it legible *as* a ring rather than as a slightly heavier
edge. No new token: the gap is the same measure as the line.
