## 1. The square

- [x] 1.1 Red → green: a seeded Latin square — every row and column a permutation, and more
      than one square across a run of seeds.

## 2. The cages

- [x] 2.1 Red → green: a seeded partition covering every cell exactly once.
- [x] 2.2 Red → green: every cage is orthogonally connected, and none exceeds the size bound.

## 3. The boards

- [x] 3.1 Red → green: KenKen cages labelled with an operation and its result, Killer with a
      sum.
- [x] 3.2 Red → green: every emitted envelope is accepted by `parsePuzzle`; a refused candidate
      is dropped and the next seed tried.
- [x] 3.3 Red → green: the batch reports attempts, accepted and rejection tags, and stops at a
      bounded budget.

## 4. The adapter

- [x] 4.1 A CLI that writes a batch, in the shape `build-pack.ts` established.

## 5. Evidence

- [x] 5.1 Tier 1 with counts, Tier 1b (`npm run mutation`, `npm run dry`).
