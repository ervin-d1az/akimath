# Design — the reduced home

## D1 · The preview is the compositor, not a picture of it

The `RETO DEL DÍA` card renders its expression through `MathView` and `nodeFor` — the same widget and
the same mapping the round uses. A card that described the item in text, or drew its own smaller
version, would be a second renderer to keep in agreement with the first, and the disagreement would
appear as a home showing one thing and the round showing another.

It also means the preview inherited the clipped-`=` fix for free, which is the argument in miniature.

## D2 · The subtractions each have a return phase

The rating pill is F3, the puzzle card F6, the bottom nav F5. **None is a cut**, and the tests assert
their absence for the reason rather than the fact: the rating check forbids the *words* as well as a
figure, because a greyed-out pill would be exactly what F2 must not show — a number sync could later
contradict.

The `TUS HABILIDADES` row is different: it is **dropped**, not deferred. It is the structural
difference between the two home documents, and choosing `Inicio actualizado` means losing it.

## D3 · The streak pill was never a subtraction

It shipped in a list of deferrals with a return phase of "F2" — which is this change. The two
statements were the same statement written as though they disagreed. A streak is a local calendar
fact (D17), needs no server, and is the only pill on the F2 home.

**It reads zero today**, because `DayLogStore` does not exist and `attemptDays` is passed in empty.
That is honest rather than broken, and worth a decision later: whether a zero streak should show at
all is a design question, and inventing a hide-at-zero rule here would be inventing design.

## D4 · The IO is in the route so the screen has none

`HomeScreen` takes an item and an integer. `HomeRoute` reads the pack, asks `StreakPolicy` what today
makes of the days it knows, and pushes the series. That is the same split `RoundRoute`/`RoundScreen`
already uses, and it is why the screen's eight tests pump no bundle and fake no clock.

## D5 · The home is registered inside its shell

`screen_registry.dart` builds `AppShell(child: HomeScreen(...))`, not a bare `HomeScreen`. Registered
bare it fails `screen_text_style_test` — correctly, because it has no `Material` ancestor that way,
and **a screen registered in a shape the app never builds is a gate checking something nobody
ships**.

## Alternatives rejected

- **A text preview of the challenge.** D1.
- **A greyed-out rating pill.** D2 — it is the thing F2 exists to avoid showing.
- **Hiding the streak pill at zero.** Not this change's decision to take.
- **`HomeScreen` loading its own pack.** It would need a bundle in every test that renders it.
