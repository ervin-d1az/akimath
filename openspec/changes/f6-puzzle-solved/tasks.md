## 1. The screen

- [x] 1.1 Red → green: it names the format, shows the time and the streak, and offers a way on.
- [x] 1.2 Red → green: no rating, no accuracy, no comparison, and no verdict mark.
- [x] 1.3 Register it, at the longest format name and the largest figures it can show.

## 2. The route

- [x] 2.1 Red → green: solving a board shows it; solving a sopa de letras shows it; leaving one
      unsolved does not.
- [x] 2.2 Red → green: the time is measured by the route, from opening the puzzle.
- [x] 2.3 Red → green: it replaces the board, so leaving goes home.

## 3. Figures that mean what they say

**Added during build**, and found by falsification: computing the streak inside the route's
builder made it a fact about frame scheduling rather than about the moment the player finished
— the builder runs after `_startPuzzle`'s `await` has resumed and refreshed the log, so
appending today and not appending it gave the same answer.

- [x] 3.1 Red → green: both figures are pinned when the puzzle is solved, and the streak the
      screen shows is the one the home shows behind it.

## 4. Evidence

- [x] 4.1 Tier 1 with counts, Tier 1b falsification matrix, Tier 2 on the simulator.
