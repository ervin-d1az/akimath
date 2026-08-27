## Context

See `proposal.md`. Three formats share the board. The parity gate has asserted that the reader
refuses every frozen rejection row, and that has held by luck of which faults those rows carry.

## Decisions

### D1 · The gate distinguishes faults a reader can see from faults only a search can find

`solution_not_unique` cannot be detected without solving, and `no_puzzle_generation_test` exists
precisely to keep solving off the device. So the gate stops asserting something the architecture
forbids, and instead records the exception with its reason, per kind.

The alternative — quietly dropping Kakuro from the rejection loop — is the same code with the reason
lost, which is how an exception becomes a habit. Every kind not named is still required to refuse.

### D2 · A run's clue sits on its first cell, not in a preceding blocked cell

Newspaper Kakuro puts the two sums in a split blocked cell before the run. The frozen format does
not guarantee one exists: the golden fixture has a run starting at column 0, with nothing to its
left. Anchoring to the run's own first cell always works, and carries the direction so a cell
beginning two runs can show both.

### D3 · The domain is nine, and it comes from the format

`KAKURO_DIGIT_CEILING` is 9 whatever the board's size — a third rule, after `size` and `size²`. The
board already declares its domain, so this is a value the reader sets rather than a branch anything
downstream has to learn.

## Risks / Trade-offs

- **Two clues on one small cell** → drawn at the corners in the eyebrow size the cage labels already
  use, and the 6×6 board stays registered under the overflow gate.
- **Excusing a rejection row weakens the parity gate** → the excuse is per kind, carries a reason,
  and the gate fails if an unnamed kind stops being refused.
