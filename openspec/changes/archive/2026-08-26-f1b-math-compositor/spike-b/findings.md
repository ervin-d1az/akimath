# Spike B — verdict

**Run:** 2026-08-16, iPhone 17 simulator (iOS 26.4), `flutter run` from `app/`.
**Budget:** two days. **Used:** well under one.
**Evidence:** `baseline-1.0.png`, `scaled-1.3.png`. The spike itself is deleted, per task 0.3.

---

## The criterion

> *The ugliest expression in v1, with the 3 px outline applied, legible, in two days.*

**Met.** Three cases were rendered inside a card carrying `BrandShape.borderWidth` (3) and the hard
shadow:

| Case | What it is | Reads |
|---|---|---|
| **A** | `3/4 + 2/5 =` with a focused answer slot holding `23/20` — two stacked operands, two operators and an outlined slot, all at 76 px. The densest thing v1 actually draws. | **Legible.** The 3 px card outline does not crowd the glyphs; the 3 px pink slot outline around a 46 px fraction reads clearly at a glance. |
| **B** | A nested fraction — `(1/2)/3` — which **no document in the corpus draws**. R1's early-warning signal is two days passing without one legible instance. | **Legible.** The inner bar (3 px, narrow) and the outer bar (6 px, wide) are unambiguously distinguishable, which is the whole question nesting asks. |
| **C** | The three measured sizes, 76 / 46 / 22, side by side. | All three read. At 22 the fraction is small but unambiguous. |

The outline was never the problem. R1 predicted a week of fitting a thick outline onto thin glyphs;
at 76 px Darumadrop is not thin, and the card's padding carries the outline clear of the numerals
without iteration.

**What the spike did find is two problems the outline concealed.** Both are in the layout, both
change the implementation, and neither would have surfaced from a static mock.

---

## Finding 1 — the bar must be derived from the *effective* size, not the nominal one

**The defect, seen directly:** compare the two screenshots. At `textScaler` 1.3 the numerals grow by
30 % and **the fraction bar does not grow at all** — it is a `Container` with a fixed height and a
fixed minimum width, and neither participates in text scaling. Measured off the two captures, the
bar's thickness relative to the numeral's height falls by roughly a quarter between 1.0 and 1.3.

The bar reads as correct at 1.0 and as **too thin** at 1.3. Nothing in a design document would have
caught this, because every document is drawn at one scale.

**Consequence for the API, and it is not cosmetic.** `FractionMetrics` must receive the *resolved*
font size — after text scaling — not the size the call site asked for. That makes the split sharper
than the proposal stated it:

- the **adapter** resolves `MediaQuery.textScaler.scale(size)` and the real font metrics;
- the **spec** receives two plain numbers and stays pure.

`MathNode.layout` and `FractionMetrics` therefore take an effective size, and the word *effective*
belongs in their documentation, because "size" is exactly the parameter a future caller will pass a
nominal value to.

The app is gated at `textScaler` 1.3 by `screen_overflow_test.dart`, so this is inside the range the
project already promises to support, not an edge case.

## Finding 2 — three measured rows are a test, not a rule

The plan states the geometry as three pairs — 76 → (6, 58), 46 → (4, 36), 22 → (3, 26) — and the
delta spec asserts exactly those. **That is right for a test and insufficient for an implementation.**

The spike implemented them as a step function, and Finding 1 is what exposes the gap: once text
scaling is applied, the effective size lands *between* the rows. 76 × 1.3 = 98.8, which a step
function serves with the same 6 px bar it gives 76 — proportionally too thin, which is the artefact
visible in `scaled-1.3.png`.

So the implementation needs a rule continuous across the range that **passes through all three stated
points**. Two observations to hand to it rather than decisions taken here:

- Thickness fits `max(3, round(size × 0.079))` on all three rows exactly — 76 → 6, 46 → 4, 22 → 3.
  The floor at 3 is doing real work: without it, 22 gives 2.
- Minimum bar width does **not** fit one ratio: 58/76 = 0.763 against 36/46 = 0.783. Interpolating
  between the stated points and clamping outside them is the honest reading; inventing a single
  constant would move at least one number the design measured.

**Recorded, not decided.** The three points are the design's; a curve through them is the
implementation's, and it belongs in the change with a test that pins all three rows *and* one
between them.

---

## What did not need changing

- **76 px stands.** Nothing in the render argues for 84 or 70. D2's reasoning survives contact.
- **The x-height metrics in the plan are correct**, verified by parsing the shipped TTFs rather than
  trusting the document: Darumadrop `OS/2.sxHeight` = 435/1000, Plus Jakarta = 536/1000.
  Cap heights, unrecorded until now and needed for bar placement: **590** and **745**.
- **`MathLayout` stays deferred.** The spike rendered a nested fraction with a plain `Column`, which
  is the strongest available evidence that a general box-layout engine is not what the corpus needs
  (design D6). One caution for whoever revisits it: at `textScaler` 1.3 the nested case is roughly
  600 logical pixels tall, which would not co-exist with a keypad on a 390×844 screen. That is a
  reason to keep nesting out of v1, not a reason to build the engine.

## One thing the spike is not evidence about

The spike faked the dashed focus outline with a **solid** pink border, because `f0-dashed-border` is
not built. The width and the colour are therefore tested and the **pattern is not**. Whether a dashed
3 px pink outline still reads as an input affordance at slot size is that change's question, and it
is listed here so nobody mistakes this verdict for covering it.
