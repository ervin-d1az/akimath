## Why

The board exists and one format uses it. Killer is the cheapest possible test of
whether that board was built right: it is KenKen with the operation removed —
same square, same cages, same Latin constraint, same grading — so if adding it
costs more than a reader and a label rule, the substrate is wrong and better to
learn that now than after three more kinds.

It also closes a defect the KenKen change recorded and did not fix: the pad
shows nine digits on a board that admits three, so pressing 7 does nothing at
all. A key that cannot act is the thing the preferences screen already argues
against — *a switch that does nothing is worse than an absent one*.

## What Changes

- **Killer**, read from the frozen payload and drawn on the existing board.
- **A cage may have no operation.** KenKen's carry one; Killer's carry a sum and
  nothing else, and a `3+` on a Killer cage would be a claim the format does not
  make.
- **The puzzle screen takes any caged puzzle**, rather than KenKen specifically.
- **Keys outside the board's domain are shown as unavailable**, on every puzzle
  — a 3×3 offers three digits and says so.
- **NOT in this change**: Magic Square, Kakuro, Word Search.

## Capabilities

### Modified Capabilities

- `puzzle-board`: a cage may carry a target with no operation, and the pad
  offers only digits the board can hold.
- `puzzle-content`: the reader gains a second kind.

## Impact

- `app/lib/content/model/` (the model and reader), `app/lib/features/puzzle/`
  (the screen and the pad), `packages/core` (an authored board).
- No new dependency, no change to any frozen format.
