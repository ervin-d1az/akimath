# One card per format, and a different board each day

## Why

The generator landed and the pack can now carry several boards of a kind. The home cannot show
them: it draws **one card per puzzle in the pack**, so a second KenKen puts two cards both
reading `KenKen` on the screen. `puzzle_menu_test` already says why that is wrong — *"five cards
reading 'Rompecabezas' would be five cards a player cannot choose between"* — and two identical
`KenKen` cards is the same failure in a different form.

So the pack cannot grow until the home stops listing boards and starts listing **formats**.

## What changes

- **One card per format**, named as it is now. Which board that card opens is a pure function
  of the day.
- **A day rotates the board.** With three KenKens in the pack a player gets a different one on
  three consecutive days, and the same one all day — so leaving a board and coming back
  continues it rather than replacing it.
- The pack gains **generated boards**: three KenKens and three Killers from
  `npm run build:puzzles`, plus the authored one of each of the other three formats.

## Out of scope

Remembering which boards a player has already solved. That needs storage of a kind nothing has
yet, and a rotation by day is enough to stop the pack feeling like one evening — a player who
wants a fresh KenKen tomorrow gets one.
