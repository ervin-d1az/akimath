## Why

Kakuro is the fourth format on the shared board and it corrects a claim the
parity gate has been making since the first one: *the reader refuses every
rejection row*. That was true for three formats by luck of which faults their
fixtures carry, and Kakuro's is `solution_not_unique` — which cannot be detected
without solving the board, and solving on the device is the thing this feature
is built not to do.

It also brings a third domain rule. KenKen and Killer hold 1 to `size`, a magic
square 1 to `size²`, and a Kakuro 1 to 9 whatever its size. Declaring the domain
was the right call one format earlier than it was needed.

## What Changes

- **Kakuro**, drawn on the shared board with run clues in the grid.
- **The parity gate says which faults a reader can see.** A structural fault —
  a run that leaves a cell uncovered, a solution of the wrong shape — is
  refused where the pack is read. A fault that needs a search is the builder's,
  and the gate records that rather than pretending otherwise.
- **A run's clue is anchored to the run's first cell**, carrying its direction,
  because a Kakuro's clues do not always have a blocked cell to live in.
- **NOT in this change**: Word Search.

## Capabilities

### Modified Capabilities

- `puzzle-board`: a cell may carry run clues, along and down.
- `puzzle-content`: the reader gains a fourth kind, and the parity gate
  distinguishes faults a reader can see from faults only a search can find.

## Impact

- `app/lib/content/model/`, `app/lib/features/puzzle/`, one authored board.
- No new dependency, no change to any frozen format.
