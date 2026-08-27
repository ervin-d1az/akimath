# Generate sopas de letras too

## Why

`f6-caged-generator` made KenKen and Killer mechanical and left three formats hand-authored at
one board each. The sopa de letras is the cheapest of the three to add and the one where a
single board is most obviously spent: once the eight words are found, that grid is finished
forever, in a way a KenKen someone half-remembers is not.

It is also the one whose generation is genuinely easy — placing words in a grid is not a
constraint search — so leaving it hand-authored was costing content for no reason.

## What changes

- A **pure, seeded sopa de letras generator**, judged by the same `parsePuzzle` the caged pair
  answers to. `word_occurs_twice` is a contract rejection, so a filler letter that accidentally
  spells a listed word a second time drops the candidate — detecting that here would be a
  second implementation of a rule that already exists.
- **The vocabulary is the caller's.** Which words a player meets is content, and `src/puzzles/`
  has no business holding a Spanish word list.
- The batch loop is **shared** rather than copied per format, and a proposer now names the
  reason it declined — "the squares keep repeating a digit in a cage" and "no word fits this
  grid" are different problems with different fixes.

## Out of scope

The magic square and Kakuro, which are two more different machines. And putting the generated
grids into the pack — that is a content change, and #17 is the one that made the pack able to
carry several boards of a kind.
