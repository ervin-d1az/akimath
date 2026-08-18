## 1. A cage without an operation

- [x] 1.1 Red → green: `Cage.operation` becomes optional; a KenKen cage still requires one and a
      Killer cage carries none.
- [x] 1.2 Red → green: the label shows the target alone when there is no operation, and drops the
      operation for a single-cell cage whatever the format.

## 2. Read a Killer

- [x] 2.1 Red → green: the reader parses the frozen Killer golden and refuses its rejection row.
- [x] 2.2 Red → green: the parity gate reports 2 readable, 3 pending.
- [x] 2.3 Red → green: a Killer cage that declares an operation is refused — the format has no such
      field and accepting one would let two readers disagree.

## 3. Play it

- [x] 3.1 Red → green: the screen takes any caged puzzle, not KenKen specifically.
- [ ] 3.2 Red → green: a Killer opens from the home and grades the same way.
- [x] 3.3 Register a Killer board under the design gates.

## 4. The pad offers what fits

- [x] 4.1 Red → green: keys above the board's size are shown unavailable and stay inert.
- [x] 4.2 Red → green: a 6×6 offers six and a 3×3 offers three.

## 5. Content and evidence

- [x] 5.1 Author a Killer board into the pack, and emit it.
- [ ] 5.2 Tier 1 across all stacks with counts; Tier 1b falsification matrix; Tier 2 on the
      simulator.
