# Design — the verdict encoding

## D1 · No colour on the type, so hue-only is unrepresentable

`Verdict` could carry a `color` and a `shape` and document that both must be used. That documents a
rule; it does not enforce one. A type with **no colour member** makes "communicate the result by
hue alone" something a call site cannot express — it has to reach for the outline or the glyph,
because that is all there is.

This is the same construction that made the answer-never-travels invariant true in
`packages/contract`: the sync endpoint does not accept an `ok` field.

## D2 · Two channels, and only one of them is guaranteed free

The obvious reading is "solid means right, dashed means wrong, done". It does not survive contact
with `ItemTermTile`, whose `unknown` state is **already** yellow + 3 px dashed + `?` on five of the
six stimulus screens. On that widget, `Verdict.wrong` claiming the dash would collide with "still to
fill" — reintroducing exactly the ambiguity BRD-1 exists to remove, on six screens.

So `Verdict` carries **both** channels and they are not equal in status:

- **The glyph is mandatory at every call site.** It is the channel nothing else has spent.
- **The outline is honoured where it is free.**

Which channel `unknown` gives up is DR-4 — a design decision, not one to take in code.

## D3 · The greyscale test is the real one

Asserting `correct.outline != wrong.outline` is weak: it passes for two arbitrary enum values. The
assertion that means something is that the two **render** differently with colour stripped, because
that is the reader BRD-1 is about.

## D4 · Why the progress-dot scenario is not here

It used to be, naming `app/test/features/round/ui/item_progress_dots_test.dart` — a file under a
feature that does not exist until `f2-core-loop`, which depends on this change. Naming a test *is*
an ordering edge under `openspec/config.yaml`, so that was a cycle. The scenario lives in
`f2-core-loop` verbatim; this change verifies the type and its adapter, where it can actually go red.

## Alternatives rejected

- **`Verdict` with a `.color`.** D1 — it documents the rule instead of enforcing it.
- **A colour-blind mode toggle.** An invariant behind a setting is not an invariant (D6).
- **Shape only, no hue.** The hue is real information for readers who can see it; the point is that
  it is never the *only* information.
