# Design

## D1 — Kakuro's one structural difference

The other four formats partition the board: a cell belongs to exactly one cage, one line, one
grid. Kakuro's runs **cross**, so a cell belongs to a horizontal run *and* a vertical one, and
the contract's coverage rule is "in at least one" rather than "in exactly one".

The consequence is a refusal the others do not have. A cell whose horizontal and vertical runs
are both a single cell is in no run, can never be deduced, and the contract refuses the board as
`cage_coverage_incomplete`. A random blocked pattern produces that regularly — around a third of
attempts — so the generator checks it **before** filling and names it, which keeps a collapse in
hit rate legible as a pattern problem rather than a solver one.

## D2 — The printed fraction, measured

| | 0.35 | 0.5 | 0.6 |
|---|---|---|---|
| 4×4 | 6/40 | **19/40** | 22/40 |
| 5×5 | 2/40 | **12/40** | 13/40 |
| 6×6 | 3/40 | 4/40 | 7/40 |

The jump is between 0.35 and 0.5. Going on to 0.6 buys almost nothing and prints three fifths of
the answer, so 0.5 is where the returns stop. A 3×3 keeps 0.35 — it already accepts 8 of 40, and
the fraction that rescues a 5×5 would hand a small board over.

## D3 — Fail fast on a structurally impossible run

`fillBoard` first refuses any run longer than nine cells. That case cannot arise through
`kakuroCandidate` — runs top out at six — but it is what makes the guard **testable**, and
finding it by backtracking instead costs `9!` dead ends, which timed the test out under Stryker
before this check existed.

`drawBelow` was split out of `intBetween` on the same reasoning: a bound unreachable by
construction is exactly the kind that rots unverified.
