# Design — the app shell

## D1 · The staging rule is consumed, not merely tested

`visibleTabs` could have been written, tested, and left with no caller until F5 — at which point it
would be a rule nobody had ever run. Instead `AppShell` asks it on every build and builds whatever
it returns, which today is nothing.

The bar itself is **injected** rather than imported, because `AppBottomNav` does not exist. That is
what lets the rule have a real consumer now: a test passes two roots and a builder and asserts the
builder is called with both tabs in declaration order; another passes one root and asserts it is not
called at all. When the bar lands it becomes the default and nothing else moves.

This is the `MathTone.muted` lesson applied before the fact — a value or a rule with no producer is
coverage nobody has.

## D2 · Declaration order, not insertion order

`visibleTabs` returns tabs in the order the design draws them, filtered by which have roots. Ordering
by registration would make a tab's position depend on which root happened to initialise first, which
is a bar that moves under the player between builds.

## D3 · The banner does not reuse `Verdict`, and that is deliberate

The plan says the variant map returns a `Verdict` alongside the copy, so the glyph is not optional.
The intent is right and the type is wrong: `Verdict` is right-or-wrong and carries exactly two
glyphs, and the no-connection banner needs **wifi-off**, which is neither.

Widening `Verdict` to fit a banner would produce a verdict type that no longer means a verdict — the
same mistake as forcing `0.6`'s rating chip through `StatPill.header`. So `BannerVisual` is a
separate type with the **same construction**: a glyph, a tone that is a role and never a `Color`, and
no way to express a banner without a glyph.

Recorded as a deviation rather than absorbed, because the plan names `Verdict` explicitly.

## D4 · There is no `offline` kind

The kinds are `error` and `notice`, because **the hue encodes whose fault it is**: *"Sin conexión no
es un error del usuario: va en amarillo."* An `offline` kind would invite a third colour for a
condition that is already covered by "nobody's fault".

## D5 · A skeleton is the shape of what is coming

The point of a skeleton is that **nothing jumps** when the content lands, so its geometry has to
match the loaded layout — a placeholder of a different size is a spinner with extra steps. The test
asserts the box, not merely that a placeholder exists.

It carries no shimmer. A shimmer is motion and motion is F8, and the test asserts no frame is
scheduled after one is built — which would catch an animation added later without a word.

`4.11 Cargando` is annotated *esqueletos, sin ruedita*, and `LoadingDots` is explicitly not to be
repurposed for a product screen. Both are asserted absent.

## Alternatives rejected

- **Rendering a disabled four-tab bar.** Three dead tabs imply three destinations the player could
  reach. Worse than no bar (D12).
- **Importing `AppBottomNav` into the shell now.** It does not exist; a stub would be a widget to
  delete rather than replace.
- **One banner widget per placement.** K7: two skins that must never differ on the parts that
  matter, kept in agreement by hand.
- **A shimmer.** F8.
