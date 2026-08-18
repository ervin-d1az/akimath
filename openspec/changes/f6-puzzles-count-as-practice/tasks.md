## 1. The screens report a commitment

- [ ] 1.1 Red → green: `PuzzleScreen` calls `onPractised` on the first value entered, once,
      and not on merely opening it.
- [ ] 1.2 Red → green: `WordSearchScreen` calls `onPractised` on the first word claimed, once,
      and not for a trace that spells nothing.
- [ ] 1.3 Red → green: neither screen accepts a `DayLogStore`.

## 2. The route records

- [ ] 2.1 Red → green: the route records the day and re-reads the log when a puzzle pops, so
      the home's streak rises without a relaunch.
- [ ] 2.2 Red → green: a series and a puzzle on the same day count once.

## 3. Evidence

- [ ] 3.1 Tier 1 with counts, Tier 1b falsification matrix, Tier 2 on the simulator.
