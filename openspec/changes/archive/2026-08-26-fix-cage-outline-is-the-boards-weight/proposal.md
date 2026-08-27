# The thick outline belongs to the board, not to every cage

## Why

Reported from play: *"some of the squares have a highlighted black border, and that disrupts the
design."*

`reactivos-puzzles.md` says the same thing, in the design's own words:

> *"El contorno grueso se reserva para el objeto (el tablero). Dentro, la jerarquía deja de ser
> grosor y pasa a ser **peso, color y trazo**: así conviven tres niveles sin que la celda se
> ahogue."*

It lists four levels:

| Level | Spec | The code drew |
|---|---|---|
| Board (the object) | `3px` solid ink + hard shadow | **nothing — no frame at all** |
| Cells | `1.5px`, ink at 18 % | `2px` in `muted` |
| Cage (KenKen / Killer) | `2.5px` **dashed pink** | **`3px` solid ink** |
| Block (Killer 2×3) | `3px` solid ink | — |

So a cage was drawn in the treatment reserved for the board itself, and on a board where most
cells touch a cage boundary that is most of the grid in the heaviest stroke the app has — while
the board, the one thing entitled to that weight, had no outline at all.

`DashSpec.kenKenCage` has existed unused this whole time, which says the intent was there and
the drawing was not.

## What changes

- The board is a framed object: 3 px ink and a hard shadow.
- Cells step down to a 1.5 px hairline at 18 % ink.
- Cages become 2.5 px dashed pink, drawn per edge by a painter, since a cage is a union of
  cells and only its outer sides are on the boundary.

## Out of scope

Painting the grid as one set of hairlines instead of per-cell boxes, which the digest also
describes. The per-cell boxes are what carry the selected-cell fill, and the visible difference
is a doubled hairline on shared edges at 18 % opacity.
