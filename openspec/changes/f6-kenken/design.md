## Context

See `proposal.md` — Why. What shapes the approach:

- `BoardSchema` — a 3–6 square with `blocked`, `given` and `solution` — backs KenKen, Kakuro, Killer
  and Magic Square. Only Word Search is structurally different.
- The 5×2 `KeypadLayout.puzzle` already exists and is wired to nothing.
- `checkUniqueSolution` and the cage-coverage checks are in `packages/contract`, on the **build**
  side. Nothing on the device needs to search.
- `screen_overflow_test` measures at 390×844 and textScaler 1.3. A 6×6 grid with cage labels is the
  tightest layout this app has attempted.
- `no_geometry_literal_test` scans `features/` for `Offset(` — a grid's geometry has to come from a
  spec, not from the widget.

## Goals / Non-Goals

**Goals:** a board four formats can reuse; KenKen end to end, from the pack to a solved verdict; the
fixture parity gate extended to puzzles.

**Non-Goals:** the other four kinds — each is its own change. No solver, no generator, no hints, no
timer. No change to the frozen formats.

## Decisions

### D1 · KenKen first, because it uses all of the substrate

Killer is KenKen with the operation removed; Magic Square is the board with margin targets and no
cages; Kakuro is runs rather than cages. KenKen exercises cages, an operation, a Latin-square
constraint and a graded solution — so building it first means the other three are additions to a
proven board rather than three parallel guesses at what a board needs.

Word Search is deliberately last: it shares nothing but the pack envelope.

### D2 · The board's geometry is a pure spec

`no_geometry_literal_test` scans `features/` for `Offset(`, and a grid is nothing but offsets. Cell
rectangles, cage-border segments and label anchors are computed by a pure module under
`design/**/spec/` and consumed by the widget — the same split `figurate_layout.dart` already uses,
and for the same reason: the arithmetic is testable without a `Canvas`.

### D3 · Cage borders are drawn from set membership, not authored

A cage is a list of cells. Its outline is the edges those cells do not share with each other, which
is derivable — so the payload does not carry it and cannot disagree with itself. The dashed inner
border is a property of the cage's shape, computed once.

### D4 · A wrong entry is not marked as it is made

The board reports solved or not solved, and nothing else. A grid that reddened a cell the moment it
disagreed with the solution would let a player brute-force it one digit at a time, and the solution
is on the device precisely because grading has to work offline.

This is the same reasoning that keeps `terms[unknownIndex]` off the screen for a number series.

### D5 · The puzzle is a full-screen session, like a series

`fullScreenSession` already exists and is what a round uses: no bottom bar, no navigation
affordance, one deliberate way out. A puzzle is a longer commitment than an item, so the argument is
stronger, not weaker.

### D6 · Boards are authored into the builder's content, and checked at build time

`checkUniqueSolution` runs where the pack is built. The device trusts the pack, which is the whole
reason the check exists on the other side — a phone that had to verify uniqueness before drawing
would take seconds and drain a battery to learn what the builder already knew.

## Risks / Trade-offs

- **A 6×6 grid at textScaler 1.3 may not fit with cage labels** → the largest board is registered
  under the overflow gate from the first commit, not added once it looks right. If it does not fit,
  the cap is a content decision (author 5×5) rather than a layout hack.
- **Cage outlines are fiddly** → derived from set membership and unit-tested as pure geometry before
  a widget draws anything.
- **Authoring valid KenKen boards by hand is slow** → the frozen fixtures supply one, and the
  builder refuses anything the validator rejects, so a bad hand-authored board fails the build
  rather than reaching a player.
- **The puzzle keypad is built but unproven** → it is exercised end to end here for the first time,
  and that is worth knowing before four more kinds depend on it.

## Migration Plan

None. Packs without puzzles stay valid — `puzzles` is already an array and is already empty.
