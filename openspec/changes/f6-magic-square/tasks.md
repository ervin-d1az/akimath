## 1. The domain is the board's, not a derivation

- [ ] 1.1 Red → green: `PuzzleBoard` carries the largest value it holds; entry and the pad read it.
- [ ] 1.2 Red → green: a caged board's domain is its size, a magic square's is its size squared.

## 2. Read a magic square

- [ ] 2.1 Red → green: the reader parses the golden and refuses the rejection row.
- [ ] 2.2 Red → green: a board whose domain exceeds the pad's nine digits is refused.
- [ ] 2.3 Red → green: the parity gate reports 3 readable, 2 pending.

## 3. Margin targets

- [ ] 3.1 Red → green: a target beside each row and beneath each column, each shown once.
- [ ] 3.2 Red → green: a board with no targets draws no margin.
- [ ] 3.3 Register it, and keep the overflow gate green at 1.0 and 1.3.

## 4. Content and evidence

- [ ] 4.1 Author a magic square into the pack and emit it.
- [ ] 4.2 Tier 1 with counts, Tier 1b falsification matrix, Tier 2 on the simulator.
