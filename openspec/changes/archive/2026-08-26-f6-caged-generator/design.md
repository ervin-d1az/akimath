# Design

## D1 — Propose and dispose, never propose and repair

The generator builds a candidate and hands it to `parsePuzzle`. If the contract refuses it,
the candidate is dropped and the next seed is tried.

The alternative — nudging a rejected board until it passes — needs the generator to know *why*
it failed and what would fix it, which is a second implementation of the solver. Two
implementations of "uniquely solvable" is R2 with the highest possible stakes: the disagreement
surfaces as a board a player cannot finish, offline, with no way to report it.

Dropping is also cheap. The board is 3×3 to 6×6 and the search has a node budget; spending ten
seeds to keep one is nothing at build time and buys the property that **every emitted board was
judged by the code that ships**.

## D2 — One partition, two formats

KenKen and Killer are the same Latin square with the same cage partition. They differ only in
what a cage declares: an operation and its result, or a sum with no operator. So the square and
the partition are shared and only the cage-labelling differs — which is also why doing them
together is barely more work than doing one.

They are *not* unified further than that. `checkKenKen` rejects a one-cell `−` or `÷` cage;
`checkKiller` has no such rule. Those belong to the contract and are not restated here.

## D3 — The Latin square is shuffled, not cyclic

`L[r][c] = ((r + c) mod n) + 1` is a Latin square and is one line. Used alone, every KenKen in
the pack is the same puzzle wearing different cages — the diagonal structure is visible and,
once a player notices it, permanent.

So rows, columns and symbols are each permuted by a seeded Fisher–Yates. That does not sample
uniformly from all Latin squares, and this does not claim it does: it samples from the
`(n!)³`-sized orbit of the cyclic square, which for the sizes here is far more variety than a
pack will ever hold. Stating the limit is the point — a comment claiming uniformity would be
the defect.

## D4 — Cage sizes are bounded low, and that is a solvability heuristic

Cages grow to at most four cells. Larger cages constrain less, so the search finds more than
one solution and the contract refuses the board — the generator would still be *correct*, just
slower and emptier. The bound is stated as a heuristic that raises the hit rate, not as a rule
about what a cage may be: the contract permits bigger ones, and this generator simply does not
propose them.

## D5 — The report is part of the return value, not a log line

`generateCagedBatch` returns the boards *and* what it spent: attempts, accepted, and a count
per rejection tag. A generator that quietly produces four boards when asked for ten looks
exactly like one that was asked for four, and the difference matters at the moment someone
widens the size range and the hit rate collapses.

This is the same reason the gates in this repository print counts.
