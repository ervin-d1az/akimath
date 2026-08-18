# Finishing a puzzle should say so

## Why

Solving a board pops silently back to the home. Twenty minutes of Kakuro and the only
acknowledgement is that the screen goes away — which reads as the app losing your place rather
than as you having finished.

Every other ending in the app has a screen. A right answer gets `03 Acierto`, a wrong one gets
`04 Error`, a finished series gets its summary. A finished puzzle — the longest thing a player
can do here — gets nothing.

## What changes

- **A screen for a solved puzzle**: Aki, the format's name, how long it took, the streak, and a
  way on. The same two figures the verdict screens show, and for the same reason — they are the
  two a device can compute without a server.
- **The route holds the clock.** Neither puzzle screen has one, and adding one to both would be
  the same decision written twice; the route already stamps the day and owns `now`.
- It **replaces** the board rather than stacking on it, so leaving goes home rather than back
  to a puzzle that is already finished.

## Out of scope

Anything a server would have to agree with — no rating, no comparison, no "faster than last
time". F3 has no sync, so a figure shown here could be contradicted later, which is the same
reason the verdict screens carry two tiles and not three.
