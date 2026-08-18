## Why

`packages/contract` froze five puzzle formats — KenKen, Kakuro, Killer, Magic
Square and Word Search — with their cage coverage, run sums and a
unique-solution checker, and **nothing reads any of them**. The pack builder
emits `puzzles: []`. The app has a 5×2 puzzle keypad, built and wired to
nothing. `PUZZLE DEL DÍA` is a card the home deferred to this phase.

F6 is a phase, not a change. Four of the five formats share one substrate —
`BoardSchema`: a 3–6 square with blocked cells, given cells and a solution — so
the expensive part is the board, not the fifth puzzle. This change builds that
substrate and the one puzzle that exercises all of it, and the remaining four
follow as small changes, the way the six stimulus families did once the first
one had paid for the shell.

## What Changes

- **A puzzle board**: a grid that draws blocked, given and empty cells, takes a
  selection, and accepts digits from the puzzle keypad that already exists.
- **KenKen**, because it is the format that uses every part of the substrate —
  cages with an operation and a target, a Latin-square constraint, and a
  solution to grade against. Killer is KenKen without the operation, so building
  KenKen first makes Killer nearly free.
- **The Dart puzzle readers**, checked against `contract/fixtures/puzzle/` the
  way `stimulus_fixture_test` checks the six item families. Same mitigation,
  same reason: hand-written parsers that no generator verifies.
- **The pack carries puzzles.** The builder emits `puzzles: []` today; it gains
  an authored puzzle source. Boards are authored, never generated on demand —
  that is an invariant, and a uniqueness check that has to run on a phone before
  a player can start is not a thing anyone should ship.
- **`PUZZLE DEL DÍA` on the home**, which is the card F2 deferred here.
- **NOT in this change**: Kakuro, Killer, Magic Square and Word Search. Each is
  its own change once the board exists, and each is small.

## Capabilities

### New Capabilities

- `puzzle-board`: what a puzzle grid shows, what a player may enter into it, and
  when a board is finished or wrong.
- `puzzle-content`: how a puzzle reaches the device and what a pack may carry.

### Modified Capabilities

- `home`: the home gains the `PUZZLE DEL DÍA` card it deferred to F6.
- `pack-builder`: the builder carries puzzles rather than emitting none.

## Impact

- `app/lib/features/puzzle/` (new), `app/lib/features/home/ui/` (the card),
  `packages/core/src/pack/` (an authored puzzle source), the emitted pack.
- No new dependency. No change to the frozen puzzle formats — this reads them.
- The `no_geometry_literal` and overflow gates both bite here: a 6×6 grid at
  textScaler 1.3 is the tightest layout in the app so far.
