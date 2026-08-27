# Design — press physics

## D1 · One primitive, not a press mixin on every widget

The rule appears on ~50 elements and is identical on all of them. Two ways to encode that: a shared
primitive every pressable composes, or a mixin each widget applies.

**The primitive wins**, because the mixin version has no single place to assert the rule. A test that
checks "the keypad key travels 3,5" is a test of the keypad; a test that checks `PressableSurface`
travels by its shadow offset is a test of the language. The second one keeps being true when the
fourteenth screen arrives.

## D2 · The travel distance is read, never typed

`no_geometry_literal_test.dart` scans `design/widgets/` for `Offset(` and fails on a match. That gate
landed in `f0-invariant-tests` before this change deliberately, and it is what forces the press offset
to come from `BrandShape` rather than from a number someone typed while looking at a mock.

So the implementation is *literally* "translate by the shadow's own offset" — the surface reads its
own `shadow.offset` and moves by it. There is no table mapping widget kinds to distances, because
such a table is exactly what drifts.

Consequence worth stating: **the rule composes for free.** A surface whose shadow is (4,6) travels
(4,6); one at (3,5) travels (3,5); one at (3,4) travels (3,4). Nobody maintains that correspondence.

## D3 · A shadowless control must not silently do nothing — DR-5

*"Travel into your own shadow"* yields **zero displacement** on a surface with no shadow. The
secondary button, the ghost row, the pills, the map nodes and the nav items all carry no active style
anywhere in the corpus, so the literal rule ships them dead: pressable, functional, and visually
inert.

Two things are true at once and both are recorded rather than resolved:

1. **No document specifies a duration, a curve, a haptic, or an alternative treatment** for these.
   That is genuinely absent from the design, not overlooked here — it is design request **DR-5**.
2. **Shipping a dead control by default is worse than either answer.**

**Decision: make the absence explicit rather than silent.** `req-press-visible` requires a shadowless
surface to *name* its press treatment; constructing one without a treatment fails. That does not
invent a visual — inventing one is DR-5's job and it belongs to whoever draws it — but it converts a
silent nothing into a decision someone has to make at the call site, in the change that adds the
control.

`onPressed` still fires either way. This is about what the user sees, not about whether the press
works.

## D4 · Six controls go red on day one, and that is the correct outcome — DR-6

Six touch targets in the corpus are drawn below 48 px: the reference sheet's 44×44 close, the 60×34
toggle, `4.4`'s 40 px preset chips among them. `req-touch-target` fails on every one.

**They are not bugs to fix by growing a box.** Each is a deliberate visual decision, and enlarging the
paint would change six screens to satisfy a test. The resolution is the second scenario of
`req-touch-target`: **the hit box grows and the paint does not.** A 44×44 close control keeps drawing
at 44 and hit-tests at 48.

BRD-2d is a MUST and it fires at **F2**, not later — `Dejar la serie` is ~29 px drawn and F2 ships it.
So this is not a deferred concern.

## D5 · `IconButtonTile` belongs here, not in a later change

It is `PressableSurface` plus fixed geometry — r16, 48×48, shadow (3,4), an optional toggled fill —
and it has a consumer inside F2: the item shell's 48×48 close control.

Putting it here rather than in `f0-brand-icons` keeps the split honest: **this change owns the tile's
behaviour, that change owns the glyph inside it.** The tile renders whatever `BrandIcon` it is handed
and knows nothing about path data.

Seven controls share it because they differ only in glyph and in toggled state. A per-control widget
would be seven files agreeing about r16.

## Alternatives rejected

- **`InkWell` with a custom splash.** `NoSplash.splashFactory` is already set globally; reintroducing
  Material's press machinery to then suppress it is more code arriving at the same pixel.
- **`AnimatedContainer` for the travel.** It implies a duration and a curve, which no document
  specifies — so it would smuggle a motion decision into a change whose non-goals exclude one.
- **A `pressed` boolean threaded through each widget.** Every widget then re-derives the offset, which
  is the drift D2 exists to prevent.
- **Growing the six sub-48 controls' paint.** Rejected under D4: it changes six approved screens to
  satisfy a test that a hit box satisfies without touching a pixel.
