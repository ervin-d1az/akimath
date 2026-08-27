## 1. The square

- [x] 1.1 Red → green: a permutation of 1..size², with each target its line's total.
- [x] 1.2 Red → green: the printed cells are distinct, inside the board, in a stable order, and
      never the whole of it.
- [x] 1.3 Red → green: the printed fraction scales with size.

## 2. Refusing what cannot be verified

- [x] 2.1 Red → green: a 6×6 is refused up front by name, and the batch reports that reason.

## 3. The batch and the adapter

- [x] 3.1 Red → green: every board a batch returns is accepted by `parsePuzzle`.
- [x] 3.2 `--kind magicSquare`, with its es-MX copy beside the others.

## 4. Evidence

- [x] 4.1 Tier 1 with counts, Tier 1b (`npm run mutation`, `npm run dry`).
