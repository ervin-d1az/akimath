# Design

## D1 — Per edge, not per box

A cage is a union of cells and only its outer sides are on the boundary; `cageOutline` already
works that out from set membership and hands back four booleans per cell. So the painter takes
those and builds a `Path` of only the marked sides.

Drawing a rounded rectangle per cell instead would put a line through the middle of every
multi-cell cage — which is what a `Border` can express and a cage cannot be.

## D2 — One dash run per side

`path.computeMetrics()` yields one metric per subpath, and each side is its own subpath, so
each edge starts its dash at its own corner. Dashing a single path around the whole outline
would land a gap wherever a side happened to end mid-dash, and the corner would look chipped.

## D3 — The dash pattern already existed

`DashSpec.kenKenCage` — `on: 6, off: 4` — has been in `dash_spec.dart` unused since it was
written. The intent was recorded and the drawing never followed it. Reusing it rather than
picking a new pattern keeps that decision where it was made.

## D4 — What the frame costs

Wrapping the grid in a `CandySurface` insets it by the border, which shrinks each cell by a
little under a pixel at 4×4. `cellRect` computes from the box it is handed, so the geometry
follows automatically and nothing needed a second measurement.
