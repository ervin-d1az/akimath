# Generate caged boards in batches

## Why

The pack ships **one board per format**. A player who finishes the KenKen and comes back is
handed the same KenKen, which is not a puzzle the second time. Five formats reachable and five
boards total is a demo, not content.

Hand-authoring is what has been slowing this down, and not for lack of typing: a board has to
have exactly one solution, and the frozen validator refuses one that does not. An authored
magic square was rejected as `solution_not_unique` because two of its givens did not break the
eightfold symmetry — that is not a mistake careful typing avoids.

`CLAUDE.md` forbids generating a puzzle on demand and says they go **in batches**, which is
this: a build-time generator in `packages/core`, alongside the item templates that already
work this way.

## What changes

- A **pure, seeded generator for the caged formats** — KenKen and Killer, which share a Latin
  square and a cage partition and differ only in what a cage declares.
- **The frozen validator decides.** The generator proposes an envelope and `parsePuzzle` from
  `@akimath/contract` accepts or rejects it — the same function the pack builder and the app's
  reader answer to. A generator carrying its own idea of "solvable" would be a second
  implementation of the rules, free to disagree with the one that ships.
- A **bounded** search: a fixed number of attempts per board, and a report naming how many
  seeds were spent and which tags were refused, so a generator that is quietly producing
  nothing cannot look like one that found nothing to produce.
- The one adapter writes them, the way `build-pack.ts` does.

## Out of scope

Magic square, Kakuro and word search — three different machines, and the caged pair is the one
that covers two formats at once. Putting the generated boards **into** the shipped pack is also
separate: the home lists one card per puzzle, so a second KenKen would put two identically
named cards on it, and choosing which board a player gets is a decision with its own design.
