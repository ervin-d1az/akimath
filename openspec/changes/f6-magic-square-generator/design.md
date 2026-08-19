# Design

## D1 — Only uniqueness is in doubt

Unlike the caged formats, this one's *arithmetic* cannot be wrong: a permutation of 1..size² is
distinct by construction, and a target computed from the line it describes matches it by
definition. So the generator proposes and the contract decides exactly one thing — whether more
than one arrangement satisfies the same targets.

That makes the accept rate a pure function of how much is printed, which is why the printed
fraction is the only knob and why it was measured rather than chosen.

## D2 — 6×6 is refused by us because the validator cannot decide it

| size | 0.4 | 0.5 | 0.6 |
|---|---|---|---|
| 4×4 | 5/20 | 14/20 | **18/20** |
| 5×5 | 0/20 | 2/20 | **11/20** |
| 6×6 | 0/20 | 0/20 | 0/20 |

Every 6×6 failure is `search_budget_exhausted`, not `solution_not_unique`. The format permits
6; `SEARCH_NODE_BUDGET` cannot prove uniqueness for 36 distinct values over 36 cells.

So the generator refuses that size **before building anything**, by name. The alternative is
200 attempts at ~300 ms each producing nothing — a minute of work whose outcome was known in
advance. This is a limit of the verifier rather than of the format, which is why it is stated in
the generator and not in the schema.

## D3 — Below 0.6 the failures are the wrong kind

The temptation is to print less and call the puzzle harder. The measurements say otherwise: at
0.4 a 5×5 fails **twenty times out of twenty on the budget**, not on uniqueness. Those boards
are not harder, they are unverifiable — and shipping one means a player may be unable to finish
it, offline, with nothing to report to.

A 3×3 is exempt because it needs nothing: at 0.3 it accepts 35 of 40, and at 0.6 it would print
five of nine cells, which is most of the answer.
