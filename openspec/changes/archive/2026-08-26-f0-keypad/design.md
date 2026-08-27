# Design — the keypad

## D1 · One key, three layouts, as data

The three pads differ in what they contain and agree on everything else: border 3, radius 18, shadow
(3,5), press `translate(3,5)`. The backspace glyph is byte-identical between `TecladoReactivo` and
`TecladoPuzzle`, differing only in rendered size — 24 against 23.

So the layout is **data** and the key is **one widget**. The alternative the first draft took — three
adapters in three features — is what `components.md` calls the largest defect in plan §3, and its
concrete cost is that the codepoint contract gets re-typed three times. R2 is a drift risk, and
three copies of a rule is the mechanism.

## D2 · The two digit orders stay different

The item pad is calculator order, 7-8-9 on top. The puzzle pad is reading order, 1-2-3 on top.

That looks like an inconsistency to fix and is not: the digest states both explicitly and says not to
unify them without a design decision. A calculator that renumbers itself is worse than two orders.
One widget, two orders, held as data — which is exactly what makes the difference cheap to keep.

## D3 · The face is a type, not a nullable string

A key's face is text, an icon, or a stacked fraction. The obvious encoding — `String? label` plus
`IconData? icon` — makes every renderer branch on which one is null, and makes "both null" and "both
set" representable states nobody handles.

A sealed face type makes those unrepresentable. `req-keypad-layout-pure`'s third scenario asserts it
directly, because it is the kind of decision that is invisible in a screenshot and expensive to undo
once three features consume it.

## D4 · The keypad holds no answer rule

It reports which key was pressed. It does not accumulate an answer, does not validate one, does not
know what a valid answer looks like.

That is not fastidiousness: `ARCHITECTURE.md` §4's invariant is that the answer never travels, and
`packages/contract` already froze what a canonical answer *is*. A keypad that assembled answers would
be a second place that knows the rule, on the client, in Dart — the exact shape the contract exists
to prevent.

## D5 · `FractionGlyph` and the phase inversion

The `a/b` key face is a 15 px stacked fraction, and §4.0 originally gave `FractionGlyph` to
`f1b-math-compositor` — so an F0 change could not go green without an F1b component. The plan settled
this as decision **(a)**: raise the `plain` variant into `f0-keypad`, because the digest describes
that face as pure geometry (`a` over a 20×3 bar over `b`, gap 2) with no metric injection, unlike the
struck and editable-slot variants.

**In the event the file landed early, in `f1b-math-compositor`.** The ordering is inverted from the
plan and the outcome is not: F0 precedes F1b either way, the file exists with the `plain` variant
only, and **the invariant that keeps the split honest still holds — the plain variant takes a size
and never a `FractionMetrics`.** Recorded rather than quietly absorbed, because the plan's `Depends
on` line is now wrong in a way a later reader would otherwise have to rediscover.

## Alternatives rejected

- **Three keypad widgets, one per feature.** The first draft's shape. Three keys, three copies of the
  codepoint contract, no owner.
- **A `String?` face with a parallel icon field.** D3.
- **Letting the keypad build the answer string.** D4 — it puts an answer rule on the client.
- **`TextField` with a numeric keyboard.** Forbidden by `CLAUDE.md`, and it hands a child the system
  keyboard with everything else on it.
