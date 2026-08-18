# Design

## D1 — The same propose-and-dispose, and now literally the same loop

`f6-caged-generator` established it: build a candidate, hand it to `parsePuzzle`, drop what is
refused. This format needs it for a reason the caged pair does not have — a filler letter can
accidentally complete a second copy of a listed word, and `word_occurs_twice` is a rejection
rather than a warning.

The loop is now shared rather than copied. A proposer returns either a payload or the **name**
of the reason it declined, so the report still distinguishes "the squares keep repeating a
digit in a cage" from "no word fits this grid" from a tag the contract raised.

## D2 — Overlaps are allowed, and are the point

A cell already holding the letter a word needs counts as free. Without that, words can only sit
in disjoint lines and the grid reads as a list with padding — the thing a player notices first
about a bad sopa de letras.

## D3 — The longest-first heuristic was written, measured, and removed

Placing long words first is the obvious idea: a long word has the fewest places to go. It was
implemented, and then measured over sixty seeds:

| | with the sort | without |
|---|---|---|
| 5×5 | 5.00 words | 4.77 |
| 6×6 | 6.13 words | **6.20** |
| 8×8 | 8.00 words | 8.00 |

It is worth nothing at 8×8, a fifth of a word at 5×5, and slightly *negative* at 6×6. A
heuristic that cannot be told from chance is a claim in a comment rather than a property of
the code, so it is gone and the measurement is recorded where the claim used to be.

Words longer than the grid are still filtered out before placement — that is not a heuristic,
it is the one case where "no" is knowable without looking at the grid.

## D4 — `Ñ` is in the filler alphabet

The contract's cell is `[A-ZÑ]`. Accented letters are out by the same rule, which is why the
vocabulary is unaccented — a grid that quietly dropped the accent from `NÚMERO` would be
teaching the wrong spelling, and the format cannot print it either way.
