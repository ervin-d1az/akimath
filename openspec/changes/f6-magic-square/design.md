## Context

See `proposal.md`. Two formats shared the board and both had `domain == size`, so nothing
distinguished the two ideas. Magic Square does.

## Decisions

### D1 · The board declares its domain

`PuzzleBoard` gains the largest value a cell may hold. The entry policy and the pad read it; neither
computes one. The alternative — a `switch` on the puzzle's kind in each place that needs a domain —
puts the same fact in three files and lets them disagree, which is how a format ends up playable in
the policy and unenterable on the pad.

### D2 · A board the pad cannot express is refused at the reader

The pad is frozen at nine digits. A 4×4 magic square needs sixteen, so seven of its values could
never be typed. That is not a hard board, it is an unplayable one, and the honest place to say so is
where the pack is read — the same place a kind with no renderer is refused.

It is deliberately expressed as *the domain exceeds the pad*, not *magic squares must be 3×3*: the
limit belongs to the input surface, and if the pad ever grows the rule keeps working.

### D3 · Targets live in a margin, and the grid keeps its size

Row targets sit to the right, column targets beneath. The square itself is laid out exactly as
before — `cellRect` is untouched — and the margin is space around it, so a magic square and a KenKen
draw the same grid at the same size and only one of them has labels beside it.

## Risks / Trade-offs

- **A margin makes the widest thing on screen wider** → the board is registered at 3×3 with targets
  and the overflow gate measures it at both text scales.
- **Only 3×3 magic squares are playable** → stated as a domain limit rather than a size limit, and
  enforced where a pack is read rather than left to authoring discipline.
