## Why

Magic Square is the third format on the shared board, and it is the one that
breaks an assumption the first two hid: **a cell's domain is not the board's
size.** KenKen and Killer put 1 to `size` in each cell; a magic square puts 1 to
`size²`, each exactly once. The entry policy hardcodes the first, so it would
refuse every digit above 3 on a 3×3 magic square — every digit the puzzle is
actually made of.

The assumption was true twice and is false in general, which is the useful thing
a third format was going to find out.

## What Changes

- **A board declares the largest value it holds**, rather than the renderer and
  the entry policy each deriving one from its size.
- **Magic Square**, drawn on the same board with row and column targets in the
  margin instead of cages.
- **A board whose domain the pad cannot express is refused where it is read.**
  The 5×2 pad offers nine digits; a 4×4 magic square needs sixteen. That board
  is not hard, it is unplayable, and it must fail at the pack rather than in
  front of a player.
- **NOT in this change**: Kakuro, Word Search.

## Capabilities

### Modified Capabilities

- `puzzle-board`: the domain is declared, the margin can carry targets, and a
  board the pad cannot express is refused.
- `puzzle-content`: the reader gains a third kind.

## Impact

- `app/lib/content/model/`, `app/lib/features/puzzle/`, and one authored board.
- No new dependency, no change to any frozen format.
