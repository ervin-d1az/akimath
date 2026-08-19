## 1. The board

- [x] 1.1 Red → green: clues are their runs' totals, and no run repeats a digit.
- [x] 1.2 Red → green: every open cell is in a run, some are in two, and an isolated cell is
      refused by name before the fill.
- [x] 1.3 Red → green: the unfillable case is refused, with a control that ordinary boards fill.

## 2. The batch and the adapter

- [x] 2.1 Red → green: every board a batch returns is accepted by `parsePuzzle`.
- [x] 2.2 `--kind kakuro`, with its es-MX copy beside the others.

## 3. Evidence

- [x] 3.1 Tier 1 with counts, Tier 1b (`npm run mutation`, `npm run dry`).
