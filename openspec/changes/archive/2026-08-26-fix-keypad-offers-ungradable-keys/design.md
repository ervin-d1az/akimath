# Design

## D1 — Disable rather than remove

A hole in a four-by-four grid is worse than a key that is visibly not offered: the design's
layout is a grid, the digits sit in calculator order because of it, and dropping two keys would
either leave gaps or reflow the digits into a shape no one designed.

The pad already has the mechanism — a puzzle board disables digits above its ceiling — so this
is the existing treatment applied to a second, older instance of the same problem.

## D2 — The gate tries several positions

Unary minus goes in front of a number, the fraction slash goes between two. A check that asked
only "does `5x` parse" would call the fraction key a trap and the negate key a trap, and both
are fine. So the gate asks whether the emitted text can appear in *any* accepted answer, trying
it alone, in front, behind and between.

## D3 — The exclusion list is checked in both directions

The list is not just skipped. Each key on it is re-tested against the canonicaliser and must
still be ungradable — so if `ANSWER_SHAPES` ever grows a decimal, the gate fails and says to
take the key off the list. A one-directional exclusion would quietly keep a usable key disabled
forever.

## D4 — The strip order came from the digest, not from taste

`teclados.md` transcribes `TecladoReactivo`'s DOM order: `a/b`, `−x`, `x²`. The code had them
the other way up. Restoring the design's order also happens to put the one live operator above
the two disabled ones — which is why this is in the same change rather than filed as cosmetics.
