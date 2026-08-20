# One screen split across two, and neither one full

## Why

`Perfil` shipped yesterday with an identity row over two thirds of empty cream.
That was recorded at the time as *"thin, and honestly so"* — the figures the
design puts under the identity are F4, so leaving them out was right. Seeing it
on a phone changes the judgement: it does not read as *there is not more yet*,
it reads as *this broke*.

The cause is structural rather than an omission. `4.1 Perfil` holds identity
**plus** rating, streak, three aggregates and a history feed. Of those, rating
and the aggregates are F4 — but **days, streak and history all exist**, and they
are on `Avance`, which is also half empty. Between them the two roots hold one
designed screen, and neither is full.

`Avance` is not in the design. Four documents draw `01 Inicio`, `02 Reto`,
`03 Acierto`, `04 Error`, `05 Mapa de habilidades` and `4.1`–`4.15`; there is no
progress screen anywhere. It was invented because the shell needed a second
root and the figures needed a home. Declared rule 1 names the bar's homes as
*inicio, mapa, progreso y perfil*, and what our `Avance` shows is, line for
line, what `4.1` puts under the identity.

## What changes

- **`ProfileScreen` becomes `4.1`**, in the design's own order: the identity
  row, then the headline stat pair, then `HISTORIAL` and its list.
- **The stat pair takes the design's shape.** `4.1` draws a white `RATING` card
  beside a **yellow** `RACHA` card, both `radius 22` on `shadowButton`, each
  with an eyebrow over a Darumadrop numeral over a unit line. Ours are `DÍAS`
  and `RACHA` — two equal compact tiles today, which is neither the geometry nor
  the hierarchy. Rating is still absent; its slot is filled by the figure we
  have rather than left blank.
- **`features/progress/` is deleted.** Its policy moves to
  `features/profile/policy/history_view.dart` unchanged — it is about history,
  and history is `4.1`'s.
- **`rootsPresentToday` becomes `{home, profile}`**, and the bar draws two.
  `AppTab.progress` keeps its place in the enum and its glyph: the design names
  it a home and nobody has drawn one, which is a different fact from it not
  existing.
- **`AppTab.skills` is the next root**, at F5, and `visibleTabs` will draw it
  with nothing here touched — the same mechanism that grew the bar twice
  already.

## What is dropped, and why

**Aki and her speech bubble.** `Avance` drew her at 110 px with *"Cada día que
juegas cuenta, aunque falles."* Declared rule 5 names where she appears —
*"inicio, resultados, estados de racha y tutorial"* — and the profile is not on
that list. She is still on the screen, clipped inside the avatar tile, which is
exactly where `4.1` puts her. A warm line is a poor reason to break a rule the
same document states.

## What is still not printed

`RATING`, `+36 esta semana`, `312 RETOS`, `78% ACIERTOS`, `6,8 s PROMEDIO`. Each
is F4 or needs an aggregate no endpoint answers. `GET /me/standing` is one of
the two operations still returning 501, and `GET /me/history` reports sessions
rather than totals.
