## 1. Finding a word

- [x] 1.1 Red → green: a pure search over all eight directions, refusing a word that runs off the
      edge and one that is simply absent.
- [x] 1.2 Red → green: a claim is a straight line; a bent trace claims nothing.
- [x] 1.3 Red → green: a word traced backwards is the same word.

## 2. Read one

- [x] 2.1 Red → green: the model and reader, refusing a word its grid does not contain.
- [x] 2.2 Red → green: the parity gate reports 5 readable, 0 pending, with no exception here.

## 3. Play one

- [x] 3.1 Red → green: the grid, the word list, and a drag that claims a word.
- [x] 3.2 Red → green: found words marked without relying on hue.
- [x] 3.3 Red → green: no keypad on this screen.
- [x] 3.4 Register it at the largest size the format admits.

## 4. Reach one

**Added during build**, and the change owns it: the home's `_startPuzzle` guarded on
`is! KenKenPuzzle` and returned silently for anything else, justified by a comment reading
*"`readPuzzle` refuses a kind this build cannot draw"*. This change is what falsified that
premise — and without the routing there is no Tier 2, because a word search cannot be opened.
The card also held `pack.puzzles.first`, so four of the five shipped formats were unreachable.

- [x] 4.1 Red → green: a pure name per kind, exhaustive over the sealed type.
- [x] 4.2 Red → green: the home lists every puzzle the pack carries and each card opens its own.
- [x] 4.3 Red → green: routing is an exhaustive switch, so a sixth format outside `BoardPuzzle`
      is a compile error rather than a screen that never opens.
- [x] 4.4 Red → green: a reachability gate over the *shipped* pack, reporting a count.

## 5. Content and evidence

- [x] 5.1 Author a grid into the pack and emit it.
- [x] 5.2 Tier 1 with counts, Tier 1b matrix, Tier 2 on the simulator.
      **Tier 2 closed 2026-08-20 on the iPhone 17 simulator.**
      `integration_test/puzzle_tour_test.dart` gained a case that reads the
      formats off the live home and opens every one of them — five, including
      the sopa, which has its own screen because it has no keypad. It leaves
      through `Salir` rather than `pageBack`: a board is pushed full-screen
      with no navigation affordance, which is the design, so there is no back
      button for the harness to press.
