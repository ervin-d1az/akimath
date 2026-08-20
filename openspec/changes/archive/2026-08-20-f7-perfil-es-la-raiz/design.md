# Design

## D1 — Why the root moves rather than the label

Renaming the tab alone would leave a screen called `Perfil` that is a settings
list, which is worse than the contradiction it fixes: at least `Ajustes` was
honest about what it drew.

So the content splits along the seam a player already feels. **Who I am** —
address, account state, the way out — is the root. **What the app does** is the
stack. The gear is the hinge, and it is the design's own: `4.1` puts a 48×48
gear button at the end of the identity row and nothing else on that screen
navigates.

## D2 — The stack is pushed inside the tab, not over the shell

`fullScreenSession` is the wrong mechanism here and it is worth saying why,
because it is the one this repository reaches for. That route exists to make a
*session* — a round, a board — take the whole screen with no way out but
finishing or leaving on purpose. The group badge over `4.1`–`4.7` says the
opposite: *"Aquí sí va la barra inferior."*

So the settings screens push onto the tab's own `Navigator`, and the bar stays
underneath. That is also what makes the back control a pop rather than a state
flag on the root.

## D3 — `DetailHeader` fits its title rather than carrying six sizes

The design draws the header title at 40, 38, 34, 34, 32 and 32 across `4.2` to
`4.7`, shrinking as the words lengthen. Six magic numbers would be six chances
to pick the wrong one, and the seventh screen would have none.

`FittedBox` with `BoxFit.scaleDown` on a single line reproduces it: a short
title renders at the design's largest size and a long one shrinks exactly as far
as it must. It also survives a `textScaler` the design never considered, which
six constants would not.

## D4 — `SettingsRow`'s trailing is a slot, not an enum

`4.2` has three trailing shapes — a chevron, a value beside a chevron, and
nothing (`Cerrar sesión`). An enum would have to grow for `4.3`'s value-only
row, and `4.7`'s rows are the same widget again. A `Widget?` slot plus a
`showChevron` flag covers all four without the widget knowing what a value is.

## D5 — Two rows, and the list is honest about the gap

A list of two under a header is a thin screen, and the temptation is to draw the
other four greyed out to show they are coming. That is exactly DR-P2: a control
that cannot act reads as broken rather than as unbuilt, and a player cannot tell
"not yet" from "not for you".

The row that is genuinely close — `Accesibilidad`, whose `TAMAÑO DE TEXTO` maps
onto a text scale the app is already gated at 1.0 and 1.3 for — is the next
change, and it arrives as a row rather than as an ungreying.

## D6 — What moves and what only moves house

`AccountStateView`, the erasure door and the verdict legend are all built and
tested. None of their behaviour changes; they are re-parented. The diff should
therefore be mostly moves, and a review that finds logic changing inside one of
them has found something worth asking about.
