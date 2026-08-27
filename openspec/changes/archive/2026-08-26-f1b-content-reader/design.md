# Design — the answer rule on the client

## D1 · The fixture is read, not copied

`canon_test.dart` opens `contract/fixtures/canon.golden.json` and drives itself from what it finds.
Copying the vectors into the test would create a second source of truth — and R2 is the risk that
two implementations of one rule diverge, so a test that could go stale alongside the thing it
guards is not a guard.

It **throws** rather than skipping when the fixture is missing. A parity check that quietly does
nothing is worse than no parity check, because the suite still reports green.

## D2 · Two modes, and the strict one earns its keep immediately

`learner` normalises: spaces out, U+2044 → `/`, U+2212 → `-`, leading zeros stripped, `-0` → `0`.
`stored` refuses anything that would have to be normalised, tagging it `not_canonical`.

The asymmetry looks pedantic until it fires. Wiring `grade` through both modes **immediately failed
one of the five shipped fixture items**: `demo-4` stored `−7` with U+2212. In the old naive grading
it worked by accident; under the contract it is not canonical, and a player typing the right answer
would have seen a wrong verdict on a device with nothing reporting an error anywhere.

That is now a build failure via `pack_test.dart`, over the whole pack rather than that one item.

## D3 · Order of refusals is part of the contract

`٠` is reported as `non_ascii_digit`, not as `non_numeric` — so the character-class checks run
before the shape check. The tags are shared with TypeScript and a caller may switch on them, which
makes the order observable behaviour rather than an implementation detail.

## D4 · A refused answer is wrong, not an error

`1/0` and `x+1` are things a player can type. The round has no error state for them and inventing
one would be inventing a design (DR-K4), so grading returns `wrong`.

## D5 · A fraction is never reduced

`2/4` stays `2/4`, so it does not grade equal to `1/2`. Whether those are the same answer is a
pedagogical decision — it depends on whether the item asked for a simplified form — and this layer
does not get to take it.

## Alternatives rejected

- **A hand-rolled comparison.** What was there. Right for five fixtures and answerable to nothing.
- **Copying the vectors into the test.** D1.
- **Normalising stored answers too.** It hides broken content instead of reporting it — exactly the
  defect D2 describes, made permanent.
- **Reducing fractions.** D5.
