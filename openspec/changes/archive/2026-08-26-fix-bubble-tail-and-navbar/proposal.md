# The bubble's tail, and a nav bar that is a card

## Why

Two reports, one screenshot each.

**"The comment cloud doesn't look right."** The tail was a closed, fully stroked triangle sitting
under the bubble, with the bubble's own border running straight across its mouth — so it read as
a separate little arrow hanging off the box rather than as part of it. A speech bubble's tail is
not a triangle stuck underneath: **its inside is the bubble's inside**, and the outline runs
around the outside of both.

The seam patch the design calls for *was* implemented, and did not work: its `h=4` was measured
in the SVG's coordinate space, and the widget drew the tail 16 tall where the design's box is
18 — so the patch came out a ninth short and covered only part of a 3 px border. A patch that
removes most of a line leaves exactly the hairline that made the tail look detached.

**"Mejora el navbar para que se aline al design."** `pantallas-base.md` draws it as a floating
344×72 card — `left:20; right:20; bottom:20`, 3 px border, radius 26, the app's most common hard
shadow — with the active destination on a green `64×52` chip. The code drew a full-bleed strip
with a hairline along the top and marked selection with a small ink dot. A hairline-topped strip
is the one surface treatment nothing else in this app uses.

## What changes

- The tail's mouth is open: erase the border across it, fill, then stroke **only the two slanted
  sides**. Not stroking the top edge is simpler than covering it.
- The tail box is 18 tall, as the design draws it, so the coordinates mean what they say.
- The nav bar becomes a floating card with the app's shadow, and the active tab a green chip.

## Out of scope

The design's four nav icons. `BrandIcon` still renders stand-in characters, and the two nearest
"home" and "settings" are a tick — which means *correct* everywhere else in this app — and a
gear the system paints as a colour emoji. The labels stay until the transcribed artwork lands.
