## 1. Read a puzzle

- [ ] 1.1 Red → green: the Dart puzzle model and reader for KenKen, driven from
      `contract/fixtures/puzzle/` — golden parses, rejection row refused.
- [ ] 1.2 Red → green: a kind the app cannot draw is refused where the pack is read, and the gate
      reports how many kinds are readable and how many are pending.
- [ ] 1.3 Red → green: the pack reader carries puzzles through to the model.

## 2. The board's geometry, pure

- [ ] 2.1 Red → green: cell rectangles for sizes 3 through 6 inside a given box.
- [ ] 2.2 Red → green: a cage's outline from its cells — shared edges are interior, the rest is the
      border. Cover an L, a single cell and a disjoint pair.
- [ ] 2.3 Red → green: where a cage's target label anchors, and that two cages never anchor on the
      same cell.

## 3. The board, drawn

- [ ] 3.1 Red → green: blocked, given and open cells are told apart without hue.
- [ ] 3.2 Red → green: selection — tapping an open cell selects it, a given or blocked one does not.
- [ ] 3.3 Red → green: no open cell shows its solution value, swept with a reported count.
- [ ] 3.4 Red → green: a 6×6 board keeps every cell above the minimum touch target at 390 px.

## 4. Entry and grading

- [ ] 4.1 Red → green: pure entry — apply, replace, clear, ignore with nothing selected, refuse a
      digit outside the domain.
- [ ] 4.2 Red → green: solved only when every open cell matches the solution; full-but-wrong and
      partial are both unsolved.
- [ ] 4.3 Red → green: the board marks no individual cell wrong (design D4).

## 5. The puzzle screen

- [ ] 5.1 Red → green: the screen composes the board with the existing 5×2 puzzle keypad.
- [ ] 5.2 Red → green: it is a full-screen session with one way out, like a series.
- [ ] 5.3 Red → green: finishing shows a verdict, and leaving mid-board does not claim completion.
- [ ] 5.4 Register it under the design gates, at 3×3 and at 6×6.

## 6. Into the pack and onto the home

- [ ] 6.1 Red → green: the builder takes an authored puzzle source and emits it; a board the frozen
      validator refuses fails the build.
- [ ] 6.2 Author a KenKen board and emit it into the committed pack.
- [ ] 6.3 Red → green: `PUZZLE DEL DÍA` on the home when the pack carries one, absent when not.
- [ ] 6.4 Red → green: nothing in `app/lib/features/puzzle/` generates or solves a board.

## 7. Evidence

- [ ] 7.1 Tier 1: all four stacks green with counts stated.
- [ ] 7.2 Tier 1b: falsification matrix for the geometry, the entry policy and the grading.
- [ ] 7.3 Tier 2: the puzzle played to a solved verdict on the simulator.
